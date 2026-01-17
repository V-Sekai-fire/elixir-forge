defmodule Mix.Tasks.Certs.Gen do
  @moduledoc """
  Generates self-signed certificates for development and production webserver HTTPS.

  Creates a Certificate Authority (CA) and webserver certificates for SSL/TLS termination.

  ## Usage

      mix certs.gen

  ## Generated Files

  Creates certificates in `priv/certs/` directory:
  - `ca.crt` / `ca.key` - Certificate Authority
  - `webserver.crt` / `webserver.key` - Webserver certificate

  ## Webserver Configuration

  Use the generated certificates with Phoenix or other web servers:

  ```elixir
  # In config/prod.exs
  config :your_app, WebServer.Endpoint,
    http: [port: 4000],
    https: [
      port: 443,
      cipher_suite: :strong,
      certfile: "priv/certs/webserver.crt",
      keyfile: "priv/certs/webserver.key"
    ]
  ```
  """

  use Mix.Task

  @certs_dir "priv/certs"

  @impl Mix.Task
  def run(_args) do
    # Create certificates directory
    File.mkdir_p!(@certs_dir)

    Mix.shell().info("Generating webserver certificates...")

    # Generate CA
    Mix.shell().info("1. Generating CA certificate...")
    generate_ca()

    # Generate webserver certificate
    Mix.shell().info("2. Generating webserver certificate...")
    generate_webserver_cert()

    Mix.shell().info("Certificates generated successfully!")
    Mix.shell().info("Certificate files created in: #{@certs_dir}")
    Mix.shell().info("")
    Mix.shell().info("Webserver certificate available at:")
    Mix.shell().info("  - priv/certs/webserver.crt")
    Mix.shell().info("  - priv/certs/webserver.key")
    Mix.shell().info("  - priv/certs/ca.crt")
  end

  defp generate_ca do
    # Generate CA private key
    ca_key = X509.PrivateKey.new_rsa(2048)

    # Generate CA certificate
    ca_cert = X509.Certificate.self_signed(
      ca_key,
      "/C=US/ST=CA/L=San Francisco/O=Forge/OU=Development/CN=Forge CA",
      template: :root_ca
    )

    # Save CA certificate and key
    File.write!("#{@certs_dir}/ca.crt", X509.Certificate.to_pem(ca_cert))
    File.write!("#{@certs_dir}/ca.key", X509.PrivateKey.to_pem(ca_key))
  end

  defp generate_webserver_cert do
    # Load CA
    ca_cert = File.read!("#{@certs_dir}/ca.crt") |> X509.Certificate.from_pem!()
    ca_key = File.read!("#{@certs_dir}/ca.key") |> X509.PrivateKey.from_pem!()

    # Generate webserver private key
    webserver_key = X509.PrivateKey.new_rsa(2048)

    # Generate webserver certificate
    webserver_cert = X509.Certificate.new(
      X509.PublicKey.derive(webserver_key),
      "/C=US/ST=CA/L=San Francisco/O=Forge/OU=Web/CN=webserver",
      ca_cert,
      ca_key,
      extensions: [
        subject_alt_name: X509.Certificate.Extension.subject_alt_name([
          {:dNSName, "localhost"},
          {:dNSName, "webserver"},
          {:dNSName, "*.localhost"}
        ]),
        key_usage: X509.Certificate.Extension.key_usage([:digitalSignature, :keyEncipherment]),
        ext_key_usage: X509.Certificate.Extension.ext_key_usage([:serverAuth])
      ]
    )

    # Save webserver certificate and key
    File.write!("#{@certs_dir}/webserver.crt", X509.Certificate.to_pem(webserver_cert))
    File.write!("#{@certs_dir}/webserver.key", X509.PrivateKey.to_pem(webserver_key))
  end
end
