class Threva < Formula
  desc "Local workspace for mail, meetings, and ongoing projects"
  homepage "https://github.com/jcfischer/threva-app"
  url "https://github.com/jcfischer/threva-app/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "9dbc253438420124997eaddee3206f1d3f84e3bf66ff56a030a9475a95e1ebc0"
  license "AGPL-3.0-only"

  depends_on "bun"
  depends_on :macos
  depends_on "nats-server"

  resource "cortex" do
    url "https://github.com/the-metafactory/cortex/archive/refs/tags/v6.36.1.tar.gz"
    sha256 "b39daaf9f17695d07b78c565b0e9546c8ec710063212dfdbe2773006359fa270"
  end

  resource "adapters" do
    url "https://github.com/the-metafactory/cortex-desk-adapters/archive/refs/tags/v0.2.0.tar.gz"
    sha256 "af398436505044b4b79a62bafb2570aee96d39f1cddfa29ee837c13c7c47f679"
  end

  def cortex_tag
    "v#{resource("cortex").version}"
  end

  def step(name, *args)
    ohai "Threva install step: #{name}"
    system(*args)
  rescue BuildError
    raise "Threva install step failed: #{name}"
  end

  def install
    ENV["BUN_INSTALL_CACHE_DIR"] = buildpath/"bun-cache"
    ENV["THREVA_SOURCE_DIR"] = opt_pkgshare/"source"
    ENV["CORTEX_TAG"] = cortex_tag
    ENV["THREVA_TAG"] = "v#{version}"
    step "threva-app bun install", "bun", "install", "--frozen-lockfile"
    step "threva-app UI build", "bun", "run", "build"
    (libexec/"ui").install Dir["dist/ui/*"]
    (libexec/"cli").install Dir["src/cli/*"]
    (bin/"threva").write <<~SH
      #!/bin/sh
      export PATH="#{formula_opt_bin("bun")}:#{HOMEBREW_PREFIX}/bin:$PATH"
      exec "#{formula_opt_bin("bun")}/bun" "#{opt_libexec}/cli/threva.ts" "$@"
    SH
    cp Pathname(__dir__).parent/"scripts/sync-macos-adapters", libexec
    %w[cortex adapters].each do |name|
      resource(name).stage do
        step "#{name} bun install", "bun", "install", "--frozen-lockfile"
        if name == "cortex"
          other_arch = Hardware::CPU.arm? ? "darwin-x64" : "darwin-arm64"
          prebuilds = Pathname("node_modules/@earendil-works/pi-tui/native/darwin/prebuilds")
          (prebuilds/other_arch/"darwin-platform.node").unlink
        end
        (libexec/name).install Dir["*"]
      end
    end
    sources = pkgshare/"source"
    sources.mkpath
    cp cached_download, sources/"threva-app-v#{version}.tar.gz"
    cp resource("cortex").cached_download, sources/"cortex-#{cortex_tag}.tar.gz"
  end

  post_install_steps do
    mkdir_p "threva/bin", base: :var
    run "sync-macos-adapters", base: :libexec, args: ["{{libexec}}/adapters/mac", "{{var}}/threva/bin"],
        writable_paths: ["threva/bin"], writable_base: :var
  end

  service do
    run [opt_bin/"threva", "launch", "--config", File.expand_path("~/.config/metafactory/cortex/threva/threva.yaml"),
         "--cortex", opt_libexec/"cortex", "--log", var/"log/threva.log"]
    keep_alive true
    log_path var/"log/threva.log"
    error_log_path var/"log/threva.log"
  end

  def caveats
    <<~EOS
      Run threva setup to configure your workspace.
      The source archives are installed in #{opt_pkgshare}/source.
    EOS
  end

  test do
    assert_path_exists libexec/"ui/index.html"
    assert_path_exists libexec/"cortex/src/cortex.ts"
    assert_path_exists libexec/"adapters/bin/desk-imap.ts"
    assert_path_exists pkgshare/"source/threva-app-v#{version}.tar.gz"
    assert_path_exists pkgshare/"source/cortex-v6.36.1.tar.gz"
    assert_match "Usage", shell_output("#{bin}/threva launch 2>&1", 2)
  end
end
