local record Job
    record JobArgs
        command: string
        args: {string}
        on_exit: function(Job, integer, integer)
    end

    new: function(Job, JobArgs): Job
    start: function(Job)
    result: function(Job): {string}
end

return Job
