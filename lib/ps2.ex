defmodule PS2 do
	use Application

	# Application Entry Point
	@impl true
	def start(_type, _args) do
		DummySupervisor.start_link(name: DummySupervisor)
	end
end
