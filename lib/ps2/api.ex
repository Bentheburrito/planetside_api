defmodule PS2.API do
	use HTTPoison.Base

	alias PS2.API.Query

	def process_url(query), do: "https://census.daybreakgames.com/s:#{Application.fetch_env!(:ps2, :serviceid)}/get/ps2:v2/" <> query

	def query(query) when is_bitstring(query) do
		case get(query) do
			{:ok, res} -> Jason.decode(res.body) # Expand to handle decoding errors
			{:error, e} -> {:error, e}
		end
	end
	def query(%Query{} = q), do: query(to_string(q))
end
