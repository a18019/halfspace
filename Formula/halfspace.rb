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
    # アクセシビリティ権限を維持するためにアドホック署名
    system "codesign", "-f", "-s", "-", ".build/release/halfspace"
    bin.install ".build/release/halfspace"
  end

  service do
    run [opt_bin/"halfspace"]
    keep_alive true
  end

  test do
    assert_match "halfspace", shell_output("#{bin}/halfspace --help 2>&1", 1)
  end
end
