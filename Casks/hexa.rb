# SPDX-License-Identifier: GPL-3.0-or-later
cask "hexa" do
  version "0.3.0"
  sha256 "969a609e15bed120747725977b039657a51c875a67b09a36028e9cbe85352ee4"

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
