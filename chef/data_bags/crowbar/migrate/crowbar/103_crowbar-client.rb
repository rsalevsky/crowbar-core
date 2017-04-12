def upgrade(ta, td, a, d)
  unless a["users"].key?("crowbar-client")
    a["users"]["crowbar-client"] = ta["users"]["crowbar-client"]
  end
  return a, d
end

def downgrade(ta, td, a, d)
  unless ta["users"].key?("crowbar-client")
    a.delete["users"]["crowbar-client"]
  end
  return a, d
end
