class ForceCreatePlaygroundUuidConstraint < Neo4j::Migrations::Base
  def up
    add_constraint :Playground, :uuid, force: true
  end

  def down
    drop_constraint :Playground, :uuid
  end
end
