#!/usr/bin/env bash
# Downloads static TTFs for TemplateFontCatalog (google_fonts bundled assets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/assets/google_fonts"
LIC="$DIR/licenses"
mkdir -p "$LIC"
download() {
  local name=$1 hash=$2
  curl -sfL "https://fonts.gstatic.com/s/a/${hash}.ttf" -o "$DIR/${name}.ttf"
  echo "Wrote ${name}.ttf"
}
download Roboto-Regular d1d7c5f4500eeb1a09e051781906c3642015a3f6c9b69046b905c8bf34c6ad60
download Roboto-Medium ec3a64e46e2ee5f546845582e1d5409107780cef55bc43b052ee962f9807aee6
download Roboto-Bold 05b2d0935046846efe2c8786ad1c5d909a11c3431787eea52f2fc70f2a8a6edf
download OpenSans-Regular e7d1b7879cdd87c63fcc8d266ac809e8e4af507694633638de3c89fc9120b4ab
download OpenSans-Medium a8496c5a42a57ee2bf5fdab6e10b9258496e99f276727c7f94859f40ca39c34e
download OpenSans-Bold 70912d3aa6f6d974980b50d4a984b453706d6bc9708ba07f386f3b48db2aa828
download Montserrat-Regular e3bb63f2cd246ff159b0841c2bd55d0914291a93487340cfa27574cc8d1861dd
download Montserrat-Medium 0640b607f11322748abad42219ea40d3c9d15736374ac53a8117a58dd7d0edb0
download Montserrat-Bold f7d4074869afb39d444728a57fe9d7dd18321cd8b7f94f014e8429c7a7b95c96
download Lato-Regular 5ced1045820caaac87af3f61ded09bacc90881f158d04c59dcce436fd02ad368
download Lato-Bold af2c9fa2534c5e1605d24015fabe84c697e5381b0549e4ad3a1bedc21df911ae
download Oswald-Regular 681ce58086b45449b1c6896b52a8177b593e845cc2b8651cab2cd7d061727d2b
download Oswald-Medium 766bfb7613fd305e42d2d892c69b930dcec406e7fa1b5daa7706f7bcb44ceec3
download Oswald-Bold 906b5ac6cdd32ef321357c94a6e0e271fd3582351df027cf1dc06d729e4af120
for fam in opensans montserrat lato oswald; do
  curl -sfL "https://raw.githubusercontent.com/google/fonts/main/ofl/${fam}/OFL.txt" \
    -o "$LIC/${fam}-OFL.txt"
done
curl -sfL "https://raw.githubusercontent.com/google/fonts/main/apache/roboto/OFL.txt" \
  -o "$LIC/roboto-OFL.txt"
