path='findings/cov3-cli-results.md'
ids=%w[MCP-003 MCP-004 MCP-007 MCP-008 MCP-011 MCP-012 MCP-015 MCP-016 MCP-019 MCP-020 MCP-023 MCP-024 MCP-027 MCP-028 MCP-033 MCP-038 MCP-046 MCP-067 MCP-072 MCP-075 MCP-077]
out=[]
File.readlines(path).each do |line|
  id=ids.find{|x| line.start_with?("| #{x} |")}
  if id
    out << line.sub("| #{id} |", "| #{id} [ios] |")
    out << line.sub("| #{id} |", "| #{id} [android] |")
  else
    out << line
  end
end
File.write(path,out.join)
