{
  description = "ModelKit development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    personal-config.url = "github:Ricoledan/nix-config";
  };

  outputs = { self, nixpkgs, personal-config }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" ];

      forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit system;
      });

      projectInputs = pkgs: with pkgs; [
        # Rust toolchain
        rustc
        cargo
        rustfmt
        clippy

        # Development tools
        bacon
        cargo-watch
        cargo-nextest

        # Build dependencies
        pkg-config
        openssl

        # Optional: faster builds
        sccache

        # Pre-commit hooks
        pre-commit
      ];

      shellHook = ''
        echo "🚀 Welcome to ModelKit development environment!"
        echo ""
        echo "📋 Available commands:"
        echo "  make build       - Build the project"
        echo "  make install     - Install to ~/.cargo/bin"
        echo "  make test        - Run tests"
        echo "  cargo watch      - Watch for changes and rebuild"
        echo ""
        echo "🔧 Development tools:"
        echo "  bacon            - Background code checker"
        echo "  cargo clippy     - Lint code"
        echo "  cargo fmt        - Format code"
        echo "  cargo nextest    - Better test runner"
        echo ""
        echo "💡 Project-specific:"
        echo "  modelkit --help  - After 'make install'"
        echo ""

        # Set up pre-commit hooks if they exist
        if [ -f .pre-commit-config.yaml ]; then
          echo "Setting up pre-commit hooks..."
          pre-commit install
        fi

        # Create .env file if it doesn't exist
        if [ ! -f .env ]; then
          echo "RUST_LOG=debug" > .env
          echo "Created .env file with default settings"
        fi
      '';

    in
    {
      devShells = forEachSystem ({ pkgs, system }: {
        default = pkgs.mkShell {
          # Conditionally inherit from personal config if it exists
          inputsFrom = let
            personalShell = personal-config.devShells.${system}.default or null;
          in if personalShell != null then [ personalShell ] else [ ];
          buildInputs = projectInputs pkgs;

          # Rust-specific environment variables
          RUST_BACKTRACE = 1;
          RUST_LOG = "modelkit=debug";

          # Use sccache for faster rebuilds
          RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";

          # OpenSSL configuration for macOS
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

          inherit shellHook;
        };
      });
    };
}