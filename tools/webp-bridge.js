/* tools/webp-bridge.js ― ブラウザで作ったWebPを受け取ってファイルに書く小さな窓口

   このPCには cwebp も ffmpeg も ImageMagick も入っていない。WebPを作れる
   道具はすでに手元にある ―― Chrome である。canvas.toBlob('image/webp') は
   ブラウザ内蔵のエンコーダを呼ぶので、追加のインストールも通信もいらない。

   ただしブラウザからディスクへは書けないので、受け取る側をここに置く。
   ページ（localhost:4173）から POST /save?name=... で中身を送ると、
   assets/img/ の下の指定した場所に書く。

   使い方:
     node tools/webp-bridge.js          （別のターミナルで serve.js も動かす）
   終わったら止めること。開発用で、納品物ではない。

   安全のための約束:
   - 127.0.0.1 でしか待ち受けない（外から触れない）
   - 書ける場所は assets/img/ の下だけ。.. を含む名前は拒む
   - 拡張子は .webp だけ
*/
'use strict';

const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT = 4174;
const ROOT = path.resolve(__dirname, '..', 'assets', 'img');

const server = http.createServer(function (req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');

  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  if (req.method !== 'POST' || !req.url.startsWith('/save')) {
    res.writeHead(404); res.end('no'); return;
  }

  const name = new URL(req.url, 'http://x').searchParams.get('name') || '';
  const target = path.resolve(ROOT, name);

  /* 受け取った名前をそのまま信用しない。assets/img の外へは書かない。 */
  if (!name || name.includes('..') || !target.startsWith(ROOT) || !target.endsWith('.webp')) {
    res.writeHead(400); res.end('bad name'); return;
  }

  const chunks = [];
  req.on('data', function (c) { chunks.push(c); });
  req.on('end', function () {
    const buf = Buffer.concat(chunks);
    /* 中身がWebPであることを確かめてから書く（RIFF....WEBP） */
    if (buf.length < 16 || buf.slice(0, 4).toString() !== 'RIFF' || buf.slice(8, 12).toString() !== 'WEBP') {
      res.writeHead(400); res.end('not webp'); return;
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, buf);
    console.log('書いた: ' + path.relative(ROOT, target) + '  ' + buf.length + ' bytes');
    res.writeHead(200); res.end(String(buf.length));
  });
});

server.listen(PORT, '127.0.0.1', function () {
  console.log('WebPの受け取り口: http://127.0.0.1:' + PORT + '/save?name=<相対パス>.webp');
});
