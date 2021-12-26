local record Job
    record JobArgs
        command: string
        args: {string}
        on_exit: function(Job, integer, integer)
    end

    new: function(Job, JobArgs): Job
    start: function(Job)
    shutdown: function(Job, integer, integer)
    result: function(Job): {string}
    after: function(Job, function)
end

return Job
