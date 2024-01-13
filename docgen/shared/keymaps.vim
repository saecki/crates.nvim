nnoremap <silent> <leader>ct :lua require("crates").toggle()<cr>
nnoremap <silent> <leader>cr :lua require("crates").reload()<cr>

nnoremap <silent> <leader>cv :lua require("crates").show_versions_popup()<cr>
nnoremap <silent> <leader>cf :lua require("crates").show_features_popup()<cr>
nnoremap <silent> <leader>cd :lua require("crates").show_dependencies_popup()<cr>

nnoremap <silent> <leader>cu :lua require("crates").update_crate()<cr>
vnoremap <silent> <leader>cu :lua require("crates").update_crates()<cr>
nnoremap <silent> <leader>ca :lua require("crates").update_all_crates()<cr>
nnoremap <silent> <leader>cU :lua require("crates").upgrade_crate()<cr>
vnoremap <silent> <leader>cU :lua require("crates").upgrade_crates()<cr>
nnoremap <silent> <leader>cA :lua require("crates").upgrade_all_crates()<cr>

nnoremap <silent> <leader>cx :lua require("crates").expand_plain_crate_to_inline_table()<cr>
nnoremap <silent> <leader>cX :lua require("crates").extract_crate_into_table()<cr>

nnoremap <silent> <leader>cH :lua require("crates").open_homepage()<cr>
nnoremap <silent> <leader>cR :lua require("crates").open_repository()<cr>
nnoremap <silent> <leader>cD :lua require("crates").open_documentation()<cr>
nnoremap <silent> <leader>cC :lua require("crates").open_crates_io()<cr>
