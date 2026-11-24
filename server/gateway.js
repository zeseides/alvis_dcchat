const TOKEN = GetConvar('dcchat_token', '');
const WEBHOOK = GetConvar('dcchat_webhook', '');
const INTENTS = (1 << 0) | (1 << 1) | (1 << 9) | (1 << 15);
const FATAL = [4004, 4010, 4011, 4012, 4013, 4014];
const STICKER_EXT = { 1: 'png', 2: 'png', 4: 'gif' };

let channel = '';
const pending = new Map();
const DIRECT_GIF = /^https:\/\/media\d*\.(tenor|giphy)\.com\//;
let ws, beat, seq = null, session = null, resumeUrl = null, acked = true, stopped = false;

const log = (...a) => console.log('[alvis_dcchat]', ...a);
const send = (op, d) => ws && ws.readyState === 1 && ws.send(JSON.stringify({ op, d }));

function cleanText(m) {
    let text = m.content || '';
    for (const u of m.mentions || []) {
        const name = (u.member && u.member.nick) || u.global_name || u.username;
        text = text.replaceAll(`<@${u.id}>`, `@${name}`).replaceAll(`<@!${u.id}>`, `@${name}`);
    }
    text = text.replace(/<@&\d+>/g, '@role').replace(/<#\d+>/g, '#channel');
    const images = (m.attachments || []).filter(a => (a.content_type || '').startsWith('image/')).map(a => a.url);
    for (const e of m.embeds || []) {
        if ((e.type !== 'gifv' && e.type !== 'image') || !e.thumbnail) continue;
        const direct = DIRECT_GIF.test(e.thumbnail.url || '');
        const proxy = e.thumbnail.proxy_url || '';
        images.push(direct ? e.thumbnail.url.replace(/AAAAC(\/[^/]+\.gif)$/, 'AAAAM$1') : proxy + (proxy.includes('?') ? '&' : '?') + 'animated=true');
        if (e.url && text.trim() === e.url) text = '';
    }
    for (const s of m.sticker_items || []) {
        const ext = STICKER_EXT[s.format_type];
        if (ext) images.push(`https://media.discordapp.net/stickers/${s.id}.${ext}?size=160`);
        else text += ` [${s.name}]`;
    }
    return { text, images };
}

function relay(d) {
    const { text, images } = cleanText(d);
    if (!text.trim() && !images.length) return;
    const ref = d.referenced_message && d.referenced_message.author;
    const replyTo = ref ? ref.global_name || ref.username : null;
    emit('alvis_dcchat:message', { author: d.author, member: d.member || null, text, images, replyTo });
}

function dispatch(t, d) {
    if (t === 'READY') {
        session = d.session_id;
        resumeUrl = d.resume_gateway_url;
        log(`connected as ${d.user.username}`);
    } else if (t === 'MESSAGE_CREATE') {
        if (d.channel_id !== channel || d.webhook_id || !d.author || d.author.bot) return;
        if (!(d.embeds || []).length && /^<?https?:\/\/\S+>?$/.test((d.content || '').trim())) {
            pending.set(d.id, { msg: d, timer: setTimeout(() => { pending.delete(d.id); relay(d); }, 3000) });
            return;
        }
        relay(d);
    } else if (t === 'MESSAGE_UPDATE') {
        const p = pending.get(d.id);
        if (!p || !(d.embeds || []).length) return;
        clearTimeout(p.timer);
        pending.delete(d.id);
        relay({ ...p.msg, embeds: d.embeds });
    } else if (t === 'GUILD_MEMBER_UPDATE') {
        emit('alvis_dcchat:member', d);
    }
}

function connect(resume) {
    if (stopped) return;
    ws = new WebSocket(`${(resume && resumeUrl) || 'wss://gateway.discord.gg'}/?v=10&encoding=json`);
    ws.onmessage = (e) => {
        const p = JSON.parse(e.data);
        if (p.s) seq = p.s;
        if (p.op === 10) {
            clearInterval(beat);
            acked = true;
            beat = setInterval(() => {
                if (!acked) return ws.close(4000);
                acked = false;
                send(1, seq);
            }, p.d.heartbeat_interval);
            if (resume && session) send(6, { token: TOKEN, session_id: session, seq });
            else send(2, { token: TOKEN, intents: INTENTS, properties: { os: 'linux', browser: 'alvis_dcchat', device: 'alvis_dcchat' } });
        } else if (p.op === 11) acked = true;
        else if (p.op === 1) send(1, seq);
        else if (p.op === 7) ws.close(4000);
        else if (p.op === 9) {
            if (!p.d) session = null;
            setTimeout(() => ws.close(4000), 1000 + Math.random() * 4000);
        } else if (p.op === 0) dispatch(p.t, p.d);
    };
    ws.onclose = (e) => {
        clearInterval(beat);
        if (stopped) return;
        if (FATAL.includes(e.code)) return log(`gateway closed with ${e.code}, check the bot token and that Message Content + Server Members intents are enabled`);
        setTimeout(() => connect(!!session), 5000);
    };
    ws.onerror = () => {};
}

async function start() {
    if (!TOKEN || !WEBHOOK) return log('set dcchat_token and dcchat_webhook in server.cfg');
    if (typeof WebSocket === 'undefined') return log('this FXServer build has no WebSocket in Node, update the server artifacts');
    try {
        const info = await (await fetch(WEBHOOK)).json();
        if (!info.channel_id) return log('dcchat_webhook is invalid');
        channel = info.channel_id;
        emit('alvis_dcchat:config', info.guild_id);
    } catch (e) {
        return log(`could not read webhook: ${e.message}`);
    }
    connect(false);
}

on('onResourceStop', (name) => {
    if (name !== GetCurrentResourceName()) return;
    stopped = true;
    clearInterval(beat);
    if (ws) ws.close(1000);
});

start();
