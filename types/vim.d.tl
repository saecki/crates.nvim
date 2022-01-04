-- vim: ft=teal expandtab sw=3 ts=3

global record vim
   -- TODO: Either find a way to generate these or at least find a comprehensive list to put a bunch of 'TODO' stub definitions here
   --    Sadly, there doesn't seem to be a nice way to serialize all of these
   --    since they're lazily brought in as you call them
   --    this might be the only way since user defined functions are also called here
   --    ex vim.fn["MyPlugin#MyFunction"]() so
   -- VIM_fn = record -- if record maps were a thing
   --    {string:function(...: any): (any)}
   --    mode: function(): Mode
   --    ...
   -- end
   fn: {string:function(...: any): (any)}
   cmd: function(cmd: string)
   call: function(func: string, ...: any)

   enum Mode
      "n" -- Normal
      "no" -- Operator-pending
      "nov" -- Operator-pending (forced charwise |o_v|)
      "noV" -- Operator-pending (forced linewise |o_V|)
      "no" -- Operator-pending (forced blockwise |o_CTRL-V|)
      "niI" -- Normal using |i_CTRL-O| in |Insert-mode|
      "niR" -- Normal using |i_CTRL-O| in |Replace-mode|
      "niV" -- Normal using |i_CTRL-O| in |Virtual-Replace-mode|
      "v" -- Visual by character
      "V" -- Visual by line
      "" -- Visual blockwise
      "s" -- Select by character
      "S" -- Select by line
      "" -- Select blockwise
      "i" -- Insert
      "ic" -- Insert mode completion |compl-generic|
      "ix" -- Insert mode |i_CTRL-X| completion
      "R" -- Replace |R|
      "Rc" -- Replace mode completion |compl-generic|
      "Rv" -- Virtual Replace |gR|
      "Rx" -- Replace mode |i_CTRL-X| completion
      "c" -- Command-line editing
      "cv" -- Vim Ex mode |gQ|
      "ce" -- Normal Ex mode |Q|
      "r" -- Hit-enter prompt
      "rm" -- The -- more -- prompt
      "r?" -- |:confirm| query of some sort
      "!" -- Shell or external command is executing
      "t" -- Terminal mode: keys go to the job
   end

   record InspectOptions
      depth: number
      newline: string
      indent: string
      process: function
   end
   inspect: function(any, InspectOptions): string

   record log
      record levels
         DEBUG: integer
         INFO: integer
         HINT: integer
         WARN: integer
         ERROR: integer
      end
   end
   notify: function(msg: string, log_level: integer, opts: table|nil)
   paste: function({string}, number): boolean
   schedule_wrap: function(function): function
   deep_equal: function(any, any): boolean
   deepcopy: function<T>(T): T
   defer_fn: function(function, number)
   startswith: function(string, string): boolean
   endswith: function(string, string): boolean
   gsplit: function(string, string, boolean): function(): string
   is_callable: function(any): boolean
   list_extend: function<T>({T}, {T}, number, number): {T}
   list_extend: function<T, K>({T}, {K}, number, number): {T|K}
   list_slice: function<T>({T}, number, number): {T}
   pesc: function(string): string
   split: function(string, string, boolean): {string}
   wait: function(integer)

   tbl_add_reverse_lookup: function(table)
   tbl_contains: function<T>({T}, T): boolean

   tbl_count: function(table): integer

   enum ExtendBehavior
      "error"
      "keep"
      "force"
   end
   tbl_extend: function(ExtendBehavior, table, table, ...: table): table
   tbl_extend: function<T>(ExtendBehavior, {T:any}, {T:any}, ...: {T:any}): {T:any}
   tbl_extend: function<T>(ExtendBehavior, {any:T}, {any:T}, ...: {any:T}): {any:T}
   tbl_extend: function<T,V>(ExtendBehavior, {T:V}, {T:V}, ...: {T:V}): {T:V}
   tbl_deep_extend: function(ExtendBehavior, table, table, ...: table): table
   tbl_deep_extend: function<T>(ExtendBehavior, {T:any}, {T:any}, ...: {T:any}): {T:any}
   tbl_deep_extend: function<T>(ExtendBehavior, {any:T}, {any:T}, ...: {any:T}): {any:T}
   tbl_deep_extend: function<T,V>(ExtendBehavior, {T:V}, {T:V}, ...: {T:V}): {T:V}

   tbl_filter: function<T>(function(T): (boolean), {T})
   tbl_filter: function(function(any): (boolean), {any})

   tbl_flatten: function<T>({T|{T}}): {T}
   tbl_flatten: function({any|{any}}): {any}

   tbl_isempty: function(table): boolean

   tbl_islist: function(table): boolean

   tbl_keys: function<T>({T:any}): {T}

   tbl_values: function<T>({any:T}): {T}

   tbl_map: function<A, B, C>(function(B): (C), {A:B}): {A:C}
   tbl_map: function(function(any): (any), table): table

   trim: function(string): string

   enum TypeName
      "table" "t"
      "string" "s"
      "number" "n"
      "boolean" "b"
      "function" "f"
      "nil"
      "thread"
      "userdata"
   end
   -- Technically, this should be a union of tuples since the types are dependent and this allows for invalid combos
   validate: function({string:{any, TypeName | function(any): (boolean, string), boolean | string}})
   -- should be {string:{any, TypeName, boolean} | {any, function(any): (boolean, string)}, string}}

   record Regex
      match_str: function(Regex, string): number, number
      match_line: function(Regex, number, number, number, number): number, number
   end
   regex: function(string): Regex

   -- TODO: these are a pitiful approximation of luv's types
   -- once Teal has some form of type inheritance/composition and luv.d.tl is written
   -- just steal from that
   record loop
      cwd: function(): string
      sleep: function(number)
      record Handle
         close: function(Handle)
         is_closing: function(Timer)
      end
      record Pipe
         read_start: function(Pipe, function(string, string))
         read_stop: function(Pipe)
         close: function(Pipe)
      end
      record Process
         close: function(Process)
      end
      record Timer
         start: function(Timer, number, number, function)
         close: function(Timer)
         stop: function(Timer)
         is_closing: function(Timer)
      end
      new_timer: function(): Timer

      new_pipe: function(boolean): Pipe

      -- TODO: the rest of these
      record SpawnOptions
         cwd: string
         args: {string}
         stdio: {Pipe, Pipe, Pipe}
      end
      spawn: function(string, SpawnOptions, function): Process

      read_start: function(Pipe, function(string, string))

      record FsStat
         record Time
            sec: number
            nsec: number
         end
         dev: number
         mode: number
         nlink: number
         uid: number
         gid: number
         rdev: number
         ino: number
         size: number
         blksize: number
         blocks: number
         flags: number
         gen: number
         atime: Time
         mtime: Time
         ctime: Time
         birthtime: Time
         type: string
      end
      fs_stat: function(string): FsStat

      record Dir userdata end
      fs_scandir: function(string, function(string, Dir)): Dir
      fs_scandir_next: function(Dir): string, string, string

      fs_mkdir: function(string, number, function(string, boolean)): boolean | Dir, string, string
   end

   call: function(string, ...: any): any
   in_fast_event: function(): boolean

   type NIL = record userdata end -- special nil for filling tables

   empty_dict: function(): table
   register_keystroke_callback: function(function(string), number): number

   rpcnotify: function(number, string, ...: string)
   rpcrequest: function(number, string, ...: string)

   stricmp: function(string, string): number
   str_utfindex: function(string, number): number, number
   str_byteindex: function(string, number, boolean): number

   schedule: function(function)

   schedule_wrap: function(function): function

   type_idx: boolean

   val_idx: boolean

   types: {string|number:string|number}

   record EventData --TODO: this is a vim thing, so types aren't really documented
      abort: any
      chan: number
      cmdlevel: any
      cmdtype: any
      cwd: string
      inclusive: boolean
      scope: any
      operator: any
      regcontents: any
      regname: any
      regtype: any
      visual: any
      completed_item: any
      height: any
      width: any
      row: number
      col: number
      size: any
      scrollbar: any
      changed_window: any
   end

   record highlight
      record Opts
         higroup: string
         timeout: number
         on_macro: boolean
         on_visual: boolean
         event: EventData
      end
      on_yank: function(Opts)
      range: function(
         bufnr: integer,
         ns: number,
         higroup: string,
         start: {number, number},
         finish: {number, number},
         rtype: any,
         inclusive: boolean
      )
   end

   record diagnostic
      record Severity -- would be great if this could be a tuplerecord
         {string}
         ERROR: integer
         WARN: integer
         INFO: integer
         HINT: integer
         E: integer
         W: integer
         I: integer
         H: integer
      end
      severity: Severity

      record Diagnostic
         lnum: integer -- The starting line of the diagnostic
         end_lnum: integer -- The final line of the diagnostic
         col: integer -- The starting column of the diagnostic
         end_col: integer -- The final column of the diagnostic
         severity: integer -- The severity of the diagnostic |vim.diagnostic.severity|
         message: string -- The diagnostic text
         source: string -- The source of the diagnostic
      end
      record ConfigOpts
         record UnderlineOpts
            severity: integer -- vim.diagnostic.severity
         end
         record VirtualTextOpts
            severity: integer -- vim.diagnostic.severity
            source: string
            format: function(diagnostic: Diagnostic): string
         end
         record SignsOpts
            severity: integer
            priority: integer
         end

         underline: boolean|UnderlineOpts
         virtual_text: boolean|VirtualTextOpts
         signs: boolean|SignsOpts
         float: OpenFloatOpts
         update_in_insert: boolean
         severity_sort: boolean
      end
      record GetOpts
         namespace: integer
         lnum: integer
         severity: integer -- vim.diagnostic.severity
      end
      record GotoOpts
         namespace: integer
         cursor_position: {integer, integer}
         wrap: boolean
         severity: integer -- vim.diagnostic.severity
         float: boolean|OpenFloatOpts
         win_id: integer
      end
      record OpenFloatOpts
         namespace: integer
         scope: string -- "buffer", "line" or "cursor"
         pos: integer|{integer, integer}
         severity_sort: boolean
         severity: integer -- vim.diagnostic.severity
         header: string|{string, string}
         source: string
         format: function(diagnostic: Diagnostic): string
         prefix: string|{string, string}|function(diagnostic: Diagnostic, i: integer, total: integer): string, string|nil
      end
      record SetLocListOpts
         namespace: integer
         winnr: integer
         open: boolean
         title: string
         severity: integer -- vim.diagnostic.severity
      end
      record SetQfListOpts
         namespace: integer
         open: boolean
         title: string
         severity: integer -- vim.diagnostic.severity
      end
      config: function(opts: ConfigOpts, namespace: integer|nil)
      disable: function(bufnr: integer|nil, namespace: integer|nil)
      disable: function(bufnr: integer|nil, namespace: integer|nil)
      fromqflist: function(list: {any}): {Diagnostic}
      get: function(bufnr: integer|nil, opts: GetOpts)
      get_namespace: function(namespace: integer): {string:integer}
      get_namespace: function(namespace: integer): {{string:integer}}
      get_next: function(opts: GotoOpts): Diagnostic
      get_next_pos: function(opts: GotoOpts): {integer, integer}
      get_prev: function(opts: GotoOpts): Diagnostic
      get_prev_pos: function(opts: GotoOpts): {integer, integer}
      goto_next: function(opts: GotoOpts)
      goto_prev: function(opts: GotoOpts)
      hide: function(namespace: integer|nil, bufnr: integer|nil)
      match: function(str: string, pat: string, groups: {string}, severity_map: {string:string}, defaults: {string:any}): Diagnostic|nil
      open_float: function(bufnr: integer|nil, opts: OpenFloatOpts): {integer, integer}
      reset: function(namespace: integer|nil, bufnr: integer|nil)
      set: function(namespace: integer, bufnr: integer, diagnostics: {Diagnostic}, opts: ConfigOpts|nil)
      setloclist: function(opts: SetLocListOpts)
      setqflist: function(opts: SetQfListOpts)
      show: function(namespace: integer|nil, bufnr: integer|nil, diagnostics: {Diagnostic}|nil, opts: ConfigOpts|nil)
      toqflist: function({Diagnostic}): {string:any}
   end

   record lsp
      record buf
         hover: function
      end
      buf_attach_client: function(bufnr: integer, client_id: integer)
      buf_get_clients: function(bufnr: integer)
      buf_is_attached: function(bufnr: integer, client_id: integer)
      buf_notify: function(bufnr: integer, method: string, params: string): boolean
      buf_request: function(bufnr: integer, method: string, params: table, handler: function): {number:number}, function
      buf_request_sync: function(bufnr: integer, method: string, params: table, timeout_ms: number): {number:number}, string

      record Client
         request: function(Client)
      end
      client: function(): Client
   end

   g: {string:any}
   t: {string:any}
   v: {string:any}
   env: {string:any}

   o: {string:any}

   record BufferOptions
      ai: boolean
      ar: boolean
      autoindent: boolean
      autoread: boolean
      backupcopy: string
      bh: string
      bin: boolean
      binary: boolean
      bkc: string
      bl: boolean
      bomb: boolean
      bt: string
      bufhidden: string
      buflisted: boolean
      buftype: string
      cfu: string
      channel: number
      ci: boolean
      cin: boolean
      cindent: boolean
      cink: string
      cinkeys: string
      cino: string
      cinoptions: string
      cinw: string
      cinwords: string
      cms: string
      com: string
      comments: string
      commentstring: string
      complete: string
      completefunc: string
      copyindent: boolean
      cpt: string
      def: string
      define: string
      dict: string
      dictionary: string
      efm: string
      endofline: boolean
      eol: boolean
      ep: string
      equalprg: string
      errorformat: string
      et: boolean
      expandtab: boolean
      fenc: string
      fex: string
      ff: string
      fileencoding: string
      fileformat: string
      filetype: string
      fixendofline: boolean
      fixeol: boolean
      flp: string
      fo: string
      formatexpr: string
      formatlistpat: string
      formatoptions: string
      formatprg: string
      fp: string
      ft: string
      gp: string
      grepprg: string
      imi: number
      iminsert: number
      ims: number
      imsearch: number
      inc: string
      include: string
      includeexpr: string
      inde: string
      indentexpr: string
      indentkeys: string
      indk: string
      inex: string
      inf: boolean
      infercase: boolean
      isk: string
      iskeyword: string
      keymap: string
      keywordprg: string
      kmp: string
      kp: string
      lisp: boolean
      lispwords: string
      lw: string
      ma: boolean
      makeencoding: string
      makeprg: string
      matchpairs: string
      menc: string
      ml: boolean
      mod: boolean
      modeline: boolean
      modifiable: boolean
      modified: boolean
      mp: string
      mps: string
      nf: string
      nrformats: string
      ofu: string
      omnifunc: string
      pa: string
      path: string
      pi: boolean
      preserveindent: boolean
      qe: string
      quoteescape: string
      readonly: boolean
      ro: boolean
      scbk: number
      scrollback: number
      shiftwidth: number
      si: boolean
      smartindent: boolean
      smc: number
      softtabstop: number
      spc: string
      spellcapcheck: string
      spellfile: string
      spelllang: string
      spelloptions: string
      spf: string
      spl: string
      spo: string
      sts: number
      sua: string
      suffixesadd: string
      sw: number
      swapfile: boolean
      swf: boolean
      syn: string
      synmaxcol: number
      syntax: string
      tabstop: number
      tag: string
      tagcase: string
      tagfunc: string
      tags: string
      tc: string
      textwidth: number
      tfu: string
      thesaurus: string
      thesaurusfunc: string
      ts: number
      tsr: string
      tsrfu: string
      tw: number
      udf: boolean
      ul: number
      undofile: boolean
      undolevels: number
      varsofttabstop: string
      vartabstop: string
      vsts: string
      vts: string
      wm: number
      wrapmargin: number
   end
   b: BufferOptions
   bo: BufferOptions

   record WindowOptions
      arab: boolean
      arabic: boolean
      breakindent: boolean
      breakindentopt: string
      bri: boolean
      briopt: string
      cc: string
      cocu: string
      cole: number
      colorcolumn: string
      concealcursor: string
      conceallevel: number
      crb: boolean
      cuc: boolean
      cul: boolean
      culopt: string
      cursorbind: boolean
      cursorcolumn: boolean
      cursorline: boolean
      cursorlineopt: string
      diff: boolean
      fcs: string
      fdc: string
      fde: string
      fdi: string
      fdl: number
      fdm: string
      fdn: number
      fdt: string
      fen: boolean
      fillchars: string
      fml: number
      fmr: string
      foldcolumn: string
      foldenable: boolean
      foldexpr: string
      foldignore: string
      foldlevel: number
      foldmarker: string
      foldmethod: string
      foldminlines: number
      foldnestmax: number
      foldtext: string
      lbr: boolean
      lcs: string
      linebreak: boolean
      list: boolean
      listchars: string
      nu: boolean
      number: boolean
      numberwidth: number
      nuw: number
      previewwindow: boolean
      pvw: boolean
      relativenumber: boolean
      rightleft: boolean
      rightleftcmd: string
      rl: boolean
      rlc: string
      rnu: boolean
      sbr: string
      scb: boolean
      scl: string
      scr: number
      scroll: number
      scrollbind: boolean
      scrolloff: number
      showbreak: string
      sidescrolloff: number
      signcolumn: string
      siso: number
      so: number
      spell: boolean
      statusline: string
      stl: string
      wfh: boolean
      wfw: boolean
      winbl: number
      winblend: number
      winfixheight: boolean
      winfixwidth: boolean
      winhighlight: string
      winhl: string
      wrap: boolean
   end
   w: WindowOptions
   wo: WindowOptions

   record api
      --[[
         API version Information
            neovim version: 0.6.0

            compatible: 0
            level: 8
            prerelease: false
      --]]

      --[[
         Vim Type -> Teal Type
         Boolean -> boolean
         Buffer -> integer
         Dictionary -> {string:any}
         Float -> number
         Integer -> integer
         Number -> number
         String -> string
         Tabpage -> integer
         Window -> integer
         none of the above -> any
      --]]

      nvim_buf_add_highlight: function(integer--[[Buffer]], integer--[[Integer]], string--[[String]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]]): integer--[[Integer]]
      nvim_buf_attach: function(integer--[[Buffer]], boolean--[[Boolean]], {string:any}--[[Dictionary]]): boolean--[[Boolean]]
      nvim_buf_call: function(integer--[[Buffer]], any--[[LuaRef]]): any--[[Object]]
      nvim_buf_clear_namespace: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]])--[[void]]
      nvim_buf_del_extmark: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]]): boolean--[[Boolean]]
      nvim_buf_del_keymap: function(integer--[[Buffer]], string--[[String]], string--[[String]])--[[void]]
      nvim_buf_del_mark: function(integer--[[Buffer]], string--[[String]]): boolean--[[Boolean]]
      nvim_buf_del_var: function(integer--[[Buffer]], string--[[String]])--[[void]]
      nvim_buf_delete: function(integer--[[Buffer]], {string:any}--[[Dictionary]])--[[void]]
      nvim_buf_detach: function(integer--[[Buffer]]): boolean--[[Boolean]]
      nvim_buf_get_changedtick: function(integer--[[Buffer]]): integer--[[Integer]]
      nvim_buf_get_commands: function(integer--[[Buffer]], {string:any}--[[Dictionary]]): {string:any}--[[Dictionary]]
      nvim_buf_get_extmark_by_id: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], {string:any}--[[Dictionary]]): {integer}--[[ArrayOf(Integer)]]
      nvim_buf_get_extmarks: function(integer--[[Buffer]], integer--[[Integer]], any--[[Object]], any--[[Object]], {string:any}--[[Dictionary]]): any--[[Array]]
      nvim_buf_get_keymap: function(integer--[[Buffer]], string--[[String]]): {{string:any}}--[[ArrayOf(Dictionary)]]
      nvim_buf_get_lines: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], boolean--[[Boolean]]): {string}--[[ArrayOf(String)]]
      nvim_buf_get_mark: function(integer--[[Buffer]], string--[[String]]): {integer,integer}--[[ArrayOf(Integer, 2)]]
      nvim_buf_get_name: function(integer--[[Buffer]]): string--[[String]]
      nvim_buf_get_offset: function(integer--[[Buffer]], integer--[[Integer]]): integer--[[Integer]]
      nvim_buf_get_option: function(integer--[[Buffer]], string--[[String]]): any--[[Object]]
      nvim_buf_get_var: function(integer--[[Buffer]], string--[[String]]): any--[[Object]]
      nvim_buf_is_loaded: function(integer--[[Buffer]]): boolean--[[Boolean]]
      nvim_buf_is_valid: function(integer--[[Buffer]]): boolean--[[Boolean]]
      nvim_buf_line_count: function(integer--[[Buffer]]): integer--[[Integer]]
      nvim_buf_set_extmark: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]], {string:any}--[[Dictionary]]): integer--[[Integer]]
      nvim_buf_set_keymap: function(integer--[[Buffer]], string--[[String]], string--[[String]], string--[[String]], {string:any}--[[Dictionary]])--[[void]]
      nvim_buf_set_lines: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], boolean--[[Boolean]], {string}--[[ArrayOf(String)]])--[[void]]
      nvim_buf_set_mark: function(integer--[[Buffer]], string--[[String]], integer--[[Integer]], integer--[[Integer]], {string:any}--[[Dictionary]]): boolean--[[Boolean]]
      nvim_buf_set_name: function(integer--[[Buffer]], string--[[String]])--[[void]]
      nvim_buf_set_option: function(integer--[[Buffer]], string--[[String]], any--[[Object]])--[[void]]
      nvim_buf_set_text: function(integer--[[Buffer]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]], {string}--[[ArrayOf(String)]])--[[void]]
      nvim_buf_set_var: function(integer--[[Buffer]], string--[[String]], any--[[Object]])--[[void]]
      nvim_call_atomic: function(any--[[Array]]): any--[[Array]]
      nvim_call_dict_function: function(any--[[Object]], string--[[String]], any--[[Array]]): any--[[Object]]
      nvim_call_function: function(string--[[String]], any--[[Array]]): any--[[Object]]
      nvim_chan_send: function(integer--[[Integer]], string--[[String]])--[[void]]
      nvim_command: function(string--[[String]])--[[void]]
      nvim_create_buf: function(boolean--[[Boolean]], boolean--[[Boolean]]): integer--[[Buffer]]
      nvim_create_namespace: function(string--[[String]]): integer--[[Integer]]
      nvim_del_current_line: function()--[[void]]
      nvim_del_keymap: function(string--[[String]], string--[[String]])--[[void]]
      nvim_del_mark: function(string--[[String]]): boolean--[[Boolean]]
      nvim_del_var: function(string--[[String]])--[[void]]
      nvim_echo: function(any--[[Array]], boolean--[[Boolean]], {string:any}--[[Dictionary]])--[[void]]
      nvim_err_write: function(string--[[String]])--[[void]]
      nvim_err_writeln: function(string--[[String]])--[[void]]
      nvim_eval: function(string--[[String]]): any--[[Object]]
      nvim_eval_statusline: function(string--[[String]], {string:any}--[[Dictionary]]): {string:any}--[[Dictionary]]
      nvim_exec: function(string--[[String]], boolean--[[Boolean]]): string--[[String]]
      nvim_exec_lua: function(string--[[String]], any--[[Array]]): any--[[Object]]
      nvim_feedkeys: function(string--[[String]], string--[[String]], boolean--[[Boolean]])--[[void]]
      nvim_get_all_options_info: function(): {string:any}--[[Dictionary]]
      nvim_get_api_info: function(): any--[[Array]]
      nvim_get_chan_info: function(integer--[[Integer]]): {string:any}--[[Dictionary]]
      nvim_get_color_by_name: function(string--[[String]]): integer--[[Integer]]
      nvim_get_color_map: function(): {string:any}--[[Dictionary]]
      nvim_get_commands: function({string:any}--[[Dictionary]]): {string:any}--[[Dictionary]]
      nvim_get_context: function({string:any}--[[Dictionary]]): {string:any}--[[Dictionary]]
      nvim_get_current_buf: function(): integer--[[Buffer]]
      nvim_get_current_line: function(): string--[[String]]
      nvim_get_current_tabpage: function(): integer--[[Tabpage]]
      nvim_get_current_win: function(): integer--[[Window]]
      nvim_get_hl_by_id: function(integer--[[Integer]], boolean--[[Boolean]]): {string:any}--[[Dictionary]]
      nvim_get_hl_by_name: function(string--[[String]], boolean--[[Boolean]]): {string:any}--[[Dictionary]]
      nvim_get_hl_id_by_name: function(string--[[String]]): integer--[[Integer]]
      nvim_get_keymap: function(string--[[String]]): {{string:any}}--[[ArrayOf(Dictionary)]]
      nvim_get_mark: function(string--[[String]], {string:any}--[[Dictionary]]): any--[[Array]]
      nvim_get_mode: function(): {string:any}--[[Dictionary]]
      nvim_get_namespaces: function(): {string:any}--[[Dictionary]]
      nvim_get_option: function(string--[[String]]): any--[[Object]]
      nvim_get_option_info: function(string--[[String]]): {string:any}--[[Dictionary]]
      nvim_get_proc: function(integer--[[Integer]]): any--[[Object]]
      nvim_get_proc_children: function(integer--[[Integer]]): any--[[Array]]
      nvim_get_runtime_file: function(string--[[String]], boolean--[[Boolean]]): {string}--[[ArrayOf(String)]]
      nvim_get_var: function(string--[[String]]): any--[[Object]]
      nvim_get_vvar: function(string--[[String]]): any--[[Object]]
      nvim_input: function(string--[[String]]): integer--[[Integer]]
      nvim_input_mouse: function(string--[[String]], string--[[String]], string--[[String]], integer--[[Integer]], integer--[[Integer]], integer--[[Integer]])--[[void]]
      nvim_list_bufs: function(): {integer}--[[ArrayOf(Buffer)]]
      nvim_list_chans: function(): any--[[Array]]
      nvim_list_runtime_paths: function(): {string}--[[ArrayOf(String)]]
      nvim_list_tabpages: function(): {integer}--[[ArrayOf(Tabpage)]]
      nvim_list_uis: function(): any--[[Array]]
      nvim_list_wins: function(): {integer}--[[ArrayOf(Window)]]
      nvim_load_context: function({string:any}--[[Dictionary]]): any--[[Object]]
      nvim_notify: function(string--[[String]], integer--[[Integer]], {string:any}--[[Dictionary]]): any--[[Object]]
      nvim_open_term: function(integer--[[Buffer]], {string:any}--[[Dictionary]]): integer--[[Integer]]
      nvim_open_win: function(integer--[[Buffer]], boolean--[[Boolean]], {string:any}--[[Dictionary]]): integer--[[Window]]
      nvim_out_write: function(string--[[String]])--[[void]]
      nvim_parse_expression: function(string--[[String]], string--[[String]], boolean--[[Boolean]]): {string:any}--[[Dictionary]]
      nvim_paste: function(string--[[String]], boolean--[[Boolean]], integer--[[Integer]]): boolean--[[Boolean]]
      nvim_put: function({string}--[[ArrayOf(String)]], string--[[String]], boolean--[[Boolean]], boolean--[[Boolean]])--[[void]]
      nvim_replace_termcodes: function(string--[[String]], boolean--[[Boolean]], boolean--[[Boolean]], boolean--[[Boolean]]): string--[[String]]
      nvim_select_popupmenu_item: function(integer--[[Integer]], boolean--[[Boolean]], boolean--[[Boolean]], {string:any}--[[Dictionary]])--[[void]]
      nvim_set_client_info: function(string--[[String]], {string:any}--[[Dictionary]], string--[[String]], {string:any}--[[Dictionary]], {string:any}--[[Dictionary]])--[[void]]
      nvim_set_current_buf: function(integer--[[Buffer]])--[[void]]
      nvim_set_current_dir: function(string--[[String]])--[[void]]
      nvim_set_current_line: function(string--[[String]])--[[void]]
      nvim_set_current_tabpage: function(integer--[[Tabpage]])--[[void]]
      nvim_set_current_win: function(integer--[[Window]])--[[void]]
      nvim_set_decoration_provider: function(integer--[[Integer]], {string:any}--[[Dictionary]])--[[void]]
      nvim_set_hl: function(integer--[[Integer]], string--[[String]], {string:any}--[[Dictionary]])--[[void]]
      nvim_set_keymap: function(string--[[String]], string--[[String]], string--[[String]], {string:any}--[[Dictionary]])--[[void]]
      nvim_set_option: function(string--[[String]], any--[[Object]])--[[void]]
      nvim_set_var: function(string--[[String]], any--[[Object]])--[[void]]
      nvim_set_vvar: function(string--[[String]], any--[[Object]])--[[void]]
      nvim_strwidth: function(string--[[String]]): integer--[[Integer]]
      nvim_subscribe: function(string--[[String]])--[[void]]
      nvim_tabpage_del_var: function(integer--[[Tabpage]], string--[[String]])--[[void]]
      nvim_tabpage_get_number: function(integer--[[Tabpage]]): integer--[[Integer]]
      nvim_tabpage_get_var: function(integer--[[Tabpage]], string--[[String]]): any--[[Object]]
      nvim_tabpage_get_win: function(integer--[[Tabpage]]): integer--[[Window]]
      nvim_tabpage_is_valid: function(integer--[[Tabpage]]): boolean--[[Boolean]]
      nvim_tabpage_list_wins: function(integer--[[Tabpage]]): {integer}--[[ArrayOf(Window)]]
      nvim_tabpage_set_var: function(integer--[[Tabpage]], string--[[String]], any--[[Object]])--[[void]]
      nvim_ui_attach: function(integer--[[Integer]], integer--[[Integer]], {string:any}--[[Dictionary]])--[[void]]
      nvim_ui_detach: function()--[[void]]
      nvim_ui_pum_set_bounds: function(number--[[Float]], number--[[Float]], number--[[Float]], number--[[Float]])--[[void]]
      nvim_ui_pum_set_height: function(integer--[[Integer]])--[[void]]
      nvim_ui_set_option: function(string--[[String]], any--[[Object]])--[[void]]
      nvim_ui_try_resize: function(integer--[[Integer]], integer--[[Integer]])--[[void]]
      nvim_ui_try_resize_grid: function(integer--[[Integer]], integer--[[Integer]], integer--[[Integer]])--[[void]]
      nvim_unsubscribe: function(string--[[String]])--[[void]]
      nvim_win_call: function(integer--[[Window]], any--[[LuaRef]]): any--[[Object]]
      nvim_win_close: function(integer--[[Window]], boolean--[[Boolean]])--[[void]]
      nvim_win_del_var: function(integer--[[Window]], string--[[String]])--[[void]]
      nvim_win_get_buf: function(integer--[[Window]]): integer--[[Buffer]]
      nvim_win_get_config: function(integer--[[Window]]): {string:any}--[[Dictionary]]
      nvim_win_get_cursor: function(integer--[[Window]]): {integer,integer}--[[ArrayOf(Integer, 2)]]
      nvim_win_get_height: function(integer--[[Window]]): integer--[[Integer]]
      nvim_win_get_number: function(integer--[[Window]]): integer--[[Integer]]
      nvim_win_get_option: function(integer--[[Window]], string--[[String]]): any--[[Object]]
      nvim_win_get_position: function(integer--[[Window]]): {integer,integer}--[[ArrayOf(Integer, 2)]]
      nvim_win_get_tabpage: function(integer--[[Window]]): integer--[[Tabpage]]
      nvim_win_get_var: function(integer--[[Window]], string--[[String]]): any--[[Object]]
      nvim_win_get_width: function(integer--[[Window]]): integer--[[Integer]]
      nvim_win_hide: function(integer--[[Window]])--[[void]]
      nvim_win_is_valid: function(integer--[[Window]]): boolean--[[Boolean]]
      nvim_win_set_buf: function(integer--[[Window]], integer--[[Buffer]])--[[void]]
      nvim_win_set_config: function(integer--[[Window]], {string:any}--[[Dictionary]])--[[void]]
      nvim_win_set_cursor: function(integer--[[Window]], {integer,integer}--[[ArrayOf(Integer, 2)]])--[[void]]
      nvim_win_set_height: function(integer--[[Window]], integer--[[Integer]])--[[void]]
      nvim_win_set_option: function(integer--[[Window]], string--[[String]], any--[[Object]])--[[void]]
      nvim_win_set_var: function(integer--[[Window]], string--[[String]], any--[[Object]])--[[void]]
      nvim_win_set_width: function(integer--[[Window]], integer--[[Integer]])--[[void]]
   end


   record json
      record DecodeOpts
         record Luanil
            object: boolean
            array: boolean
         end

         luanil: Luanil
      end

      encode: function(string)
      decode: function(string, DecodeOpts)
   end
end

