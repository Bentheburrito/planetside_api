defmodule PS2.API do
	use HTTPoison.Base

	alias PS2.API.Query

	def process_url(query) do
		sid = Application.fetch_env!(:planetside_api, :service_id)
		"https://census.daybreakgames.com/s:#{sid}/get/ps2:v2/" <> query
	end

	@doc """
	Sends encodes `query` to the API. Returns `{:ok, body}` if successful, where `body` is the body of the response decoded with Jason.decode/1.
	"""
	@spec query(%Query{} | url()) :: {:ok, body()} | {:error, HTTPoison.Error | Jason.DecodeError | PS2.API.Error}
	def query(query) when is_bitstring(query) do

		with {:ok, res} <- get(query),
		{:ok, %{"error" => m}} <- Jason.decode(res.body), do:
		{:error, %PS2.API.Error{message: m}}
	end
	def query(%Query{} = q), do: query(to_string(q))
end
