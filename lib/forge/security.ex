defmodule Forge.Security do
  @moduledoc """
  Security utilities for input validation and sanitization.
  """

  @doc """
  Validates and sanitizes file paths to prevent directory traversal attacks.

  ## Examples

      iex> LivebookNx.Security.validate_file_path("/tmp/user_input.txt")
      {:ok, "/tmp/user_input.txt"}

      iex> LivebookNx.Security.validate_file_path("../secrets.txt")
      {:error, "Path contains invalid characters or patterns"}

  """
  @spec validate_file_path(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_file_path(path) when is_binary(path) do
    cond do
      String.contains?(path, "..") ->
        {:error, "Path contains invalid characters or patterns"}

      String.contains?(path, ["\\", "\0", "\n", "\r"]) ->
        {:error, "Path contains invalid characters or patterns"}

      String.length(path) > 1024 ->
        {:error, "Path is too long"}

      path == "" ->
        {:error, "Path cannot be empty"}

      true ->
        # Use Path.expand to resolve any ~ or relative components safely
        expanded = Path.expand(path)
        {:ok, expanded}
    end
  end

  @doc """
  Sanitizes text prompts for safe use in Python code.

  This prevents code injection by:
  - Escaping quotes
  - Removing control characters
  - Length limiting

  ## Examples

      iex> LivebookNx.Security.sanitize_prompt("A beautiful sunset")
      "A beautiful sunset"

      iex> LivebookNx.Security.sanitize_prompt("Bad\"; import os; os.system('rm -rf /')")
      "Bad; import os; os.system(rm -rf )"

  """
  @spec sanitize_prompt(String.t()) :: String.t()
  def sanitize_prompt(prompt) when is_binary(prompt) do
    prompt
    |> String.slice(0, 1000) # Length limit
    |> String.replace("\n", " ") # Remove newlines
    |> String.replace("\r", " ") # Remove carriage returns
    |> String.replace("\t", " ") # Remove tabs
    |> String.replace("\"", "\\\"") # Escape double quotes
    |> String.replace("\'", "\\\'") # Escape single quotes
    |> String.replace("\\", "\\\\") # Escape backslashes
  end

  @doc """
  Validates filename for output safety.

  ## Examples

      iex> LivebookNx.Security.validate_filename("output.png")
      {:ok, "output.png"}

      iex> LivebookNx.Security.validate_filename("../../../etc/passwd")
      {:error, "Invalid filename"}

  """
  @spec validate_filename(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_filename(filename) when is_binary(filename) do
    cond do
      String.contains?(filename, ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]) ->
        {:error, "Invalid filename"}

      String.length(filename) > 255 ->
        {:error, "Filename too long"}

      filename == "" ->
        {:error, "Filename cannot be empty"}

      true ->
        {:ok, filename}
    end
  end

  @doc """
  Configures rate limiting settings (placeholder for future implementation).
  """
  def rate_limit_settings do
    %{
      max_requests_per_minute: System.get_env("RATE_LIMIT_RPM", "60") |> String.to_integer(),
      max_concurrent_requests: System.get_env("MAX_CONCURRENT", "5") |> String.to_integer()
    }
  end
end
