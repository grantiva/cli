path='findings/cov3-cli-results.md'
tools={'MCP-004'=>'grantiva_screenshot','MCP-008'=>'grantiva_tap','MCP-012'=>'grantiva_swipe','MCP-016'=>'grantiva_type','MCP-020'=>'grantiva_a11y_tree','MCP-024'=>'grantiva_a11y_check','MCP-028'=>'grantiva_script'}
out=File.readlines(path).map do |line|
  changed=nil
  tools.each do |id,tool|
    %w[ios android].each do |platform|
      if line.start_with?("| #{id} [#{platform}] |")
        changed="| #{id} [#{platform}] | pass | findings/evidence/cov3-cli/#{id}-fix2/ | explicit --platform #{platform}, empty scratch directory, unique request id: #{tool} returns the documented isError no-session text naming .grantiva/session.json; no JSON-RPC error |\n"
      end
    end
  end
  %w[ios android].each do |platform|
    if line.start_with?("| MCP-077 [#{platform}] |")
      changed="| MCP-077 [#{platform}] | pass | findings/evidence/cov3-cli/MCP-077-fix2/ | explicit --platform #{platform}, empty scratch directory, unique request ids: unknown tool has Error prefix; both ensure calls reject missing name; type/swipe/script report no session first; every reply is an isError result, not a JSON-RPC error |\n"
    end
  end
  if line.start_with?('| N3-16 |')
    changed=line.sub('simulator_teardown lacks the post-regeneration L63 sentence','the old findings/help/simulator_teardown.txt lacks the L63 sentence that the candidate adds')
  end
  changed || line
end
File.write(path,out.join)
