using Preferences: @load_preference, @set_preferences!, @delete_preferences!

const TAPIR_SCHEDULER_NAMES = ("default", "workstealing", "depthfirst")

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
    using TapirSchedulers: @sync_ws, @sync_df
    if TAPIR_SCHEDULER_CONFIG == "workstealing"
        const var"@tapir_sync" = var"@sync_ws"
    else
        const var"@tapir_sync" = var"@sync_df"
    end
end
# Note: ATM, we can't update this without reboot (or explicit revise) since
# `@sync_df` contains custom code.

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
