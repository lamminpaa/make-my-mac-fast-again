cask "make-my-mac-fast-again" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/lamminpaa/make-my-mac-fast-again/releases/download/v#{version}/MakeMyMacFastAgain-#{version}.dmg"
  name "Make My Mac Fast Again"
  desc "Native macOS system optimizer and cleanup utility"
  homepage "https://github.com/lamminpaa/make-my-mac-fast-again"

  depends_on macos: ">= :sonoma"

  app "MakeMyMacFastAgain.app"

  zap trash: [
    "~/Library/Preferences/io.tunk.make-my-mac-fast-again.plist",
  ]
end
