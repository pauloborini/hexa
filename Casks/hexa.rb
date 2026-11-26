# SPDX-License-Identifier: GPL-3.0-or-later
cask "hexa" do
  version "0.4.0"
  sha256 "57c23e0587d888b1a0b959f25330ed1a125c28d999030b6f4b9e417e7dfdd6f0"

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
