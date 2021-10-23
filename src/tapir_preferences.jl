using Preferences: @load_preference, @set_preferences!, @delete_preferences!

const TAPIR_SCHEDULER_NAMES = (
    # Use native task scheduler:
    "default",
    # Defined in TapirSchedulers:
    "workstealing",
    "depthfirst",
    "constantpriority",
    "randompriority",
)

function validate_tapir_scheduler(name; warn = false)
    if !(name in TAPIR_SCHEDULER_NAMES)
        msg = ""
        if warn
            @warn "$msg"
            return "default"
        else
            error(msg)
        end
    end
    return name
end

const TAPIR_SCHEDULER_CONFIG =
    validate_tapir_scheduler(@load_preference("tapir_scheduler", "default"); warn = true)
# Note: Just warn, so that the package is still loadable (for recovery)

if TAPIR_SCHEDULER_CONFIG == "default"
    const var"@tapir_sync" = Tapir.var"@sync"
else
    import TapirSchedulers
    if TAPIR_SCHEDULER_CONFIG == "workstealing"
        const var"@tapir_sync" = TapirSchedulers.var"@sync_ws"
    elseif TAPIR_SCHEDULER_CONFIG == "depthfirst"
        const var"@tapir_sync" = TapirSchedulers.var"@sync_df"
    elseif TAPIR_SCHEDULER_CONFIG == "constantpriority"
        const var"@tapir_sync" = TapirSchedulers.var"@sync_cp"
    elseif TAPIR_SCHEDULER_CONFIG == "randompriority"
        const var"@tapir_sync" = TapirSchedulers.var"@sync_rp"
    else
        @error "unknown scheduler: $TAPIR_SCHEDULER_CONFIG"
        macro tapir_sync(_ignored...)
            :(error("unknown scheduler: $TAPIR_SCHEDULER_CONFIG"))
        end
    end
end
# Note: ATM, we can't update this without reboot (or explicit revise) since
# `@sync_df` etc. contains custom code.

function set_tapir_scheduler(name)
    name = validate_tapir_scheduler(name)
    @set_preferences!("tapir_scheduler" => name)
    @info "Tapir scheduler is set to $name; please restart your Julia session"
end

function unset_tapir_scheduler()
    @delete_preferences!("tapir_scheduler")
    @info "Tapir scheduler is set to default; please restart your Julia session"
end

tapir_yield() = nothing
#=
function tapir_yield()
    @tapir_sync begin
        Tapir.@spawn Tapir.dontoptimize()
        Tapir.dontoptimize()
    end
end
=#
