# SPDX-License-Identifier: GPL-3.0-or-later
cask "hexa" do
  version "0.2.0"
  sha256 "29264d8854946b6826cc80081fe8bd3bf893e84130d29dd707de3279b63e2ca8"

  url "https://github.com/pauloborini/hexa/releases/download/v#{version}/hexa-#{version}-arm64.dmg"
  name "hexa"
  desc "Menu bar utility for macOS"
  homepage "https://github.com/pauloborini/hexa"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "hexa.app"

  auto_updates false

  caveats <<~EOS
    If /Applications already contains hexa and brew does not replace it, quit the app and overwrite it by hand.
    This tap lives in the hexa repository: brew tap pauloborini/hexa https://github.com/pauloborini/hexa
  EOS
end
