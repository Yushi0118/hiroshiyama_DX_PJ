このファイルがあると、GitHub Pages は Jekyll を通さず、リポジトリの中身を
そのまま公開する。

このサイトは素の HTML / CSS / JS だけでできていて、Jekyll の機能（テンプレート、
front matter、Liquid）は一切使っていない。にもかかわらず既定では Jekyll が
走るので、ビルドが失敗すると push が成功していてもサイトが更新されない。
実際 2026-09-09 のコミット 4c81d50 で失敗し、公開が丸一日止まった
（deployments API の state=failure で判明。ビルドログは認証が要るため未確認）。

中身は空でよい。消さないこと。