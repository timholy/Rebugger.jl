function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    precompile(Tuple{typeof(get_rebugger_modeswitch_dict)})
    precompile(Tuple{typeof(rebugrepl_init)})
end
