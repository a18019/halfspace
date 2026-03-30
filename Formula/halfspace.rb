class Halfspace < Formula
  desc "Auto-convert full-width spaces to half-width when using Japanese IME on macOS"
  homepage "https://github.com/a18019/halfspace"
  url "https://github.com/a18019/halfspace.git", tag: "v0.1.0"
  license "MIT"

  depends_on :macos

  def install
    system "swift", "build",
           "--disable-sandbox",
           "-c", "release"
    bin.install ".build/release/halfspace"
  end

  test do
    assert_match "halfspace", shell_output("#{bin}/halfspace --help 2>&1", 1)
  end
end
