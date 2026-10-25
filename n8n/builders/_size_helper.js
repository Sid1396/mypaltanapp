const byteSize = async (key, f) => {
  try { const buf = await this.helpers.getBinaryDataBuffer(0, key); if (buf && buf.length) return buf.length; } catch (e) {}
  const m = String(f.fileSize ?? '').trim().match(/^([\d.]+)\s*(B|kB|KB|MB|GB)?$/i);
  if (m) return Math.ceil(parseFloat(m[1]) * ({ b: 1, kb: 1000, mb: 1e6, gb: 1e9 })[(m[2] || 'B').toLowerCase()]);
  return Buffer.from(f.data || '', 'base64').length;
};
