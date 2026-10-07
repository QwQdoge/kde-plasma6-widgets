.pragma library

function intervalMs(source, fallback) {
    var minutes = Number(source.syncInterval || fallback || 60);
    if (!isFinite(minutes) || minutes <= 0)
        minutes = 60;
    return Math.min(minutes, 10080) * 60000;
}

function isDue(source, fallback, now) {
    var interval = intervalMs(source, fallback);
    var lastSync = Number(source.lastSync) || 0;
    if (now - lastSync <= interval)
        return false;
    var failures = Number(source.failCount) || 0;
    if (failures > 0) {
        var backoff = Math.min(interval, 60000 * Math.pow(2, Math.min(failures, 5)));
        if (now - (Number(source.lastAttempt) || 0) < backoff)
            return false;
    }
    return true;
}

function complete(source, succeeded, now) {
    source.lastAttempt = now;
    if (succeeded) {
        source.lastSync = now;
        source.failCount = 0;
    } else {
        source.failCount = Math.min(5, (Number(source.failCount) || 0) + 1);
    }
}
