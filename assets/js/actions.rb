require 'grand_central/action'

Action = GrandCentral::Action.create do
  def self.let attr, &block
    define_method attr, &block
  end
end

UpdateCode = Action.with_attributes(:language, :code)
ToggleEditor = Action.with_attributes(:language)
ToggleJS = Action.create
SetPlaygroundName = Action.with_attributes(:name)
FetchPlayground = Action.with_attributes(:id)
LoadPlayground = Action.with_attributes(:json) do
  %w(id name html css ruby).each { |attr| let(attr) { json[:playground][attr] } }
end
SavePlayground = Action.create

SetError = Action.with_attributes(:error)
DeleteError = Action.with_attributes(:error)
ClearErrors = Action.create

RedirectTo = Action.with_attributes(:path)
