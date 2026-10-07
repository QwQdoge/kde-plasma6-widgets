import QtQuick
import QtTest
import "../contents/ui/js/RSSSchedule.js" as Schedule

TestCase {
    name: "RSSSchedule"

    function test_failedFeedBackoffAndRecovery() {
        var source = {
            syncInterval: 60,
            lastSync: 0
        };
        var now = 10000000;
        verify(Schedule.isDue(source, 60, now));
        Schedule.complete(source, false, now);
        compare(source.lastSync, 0);
        verify(!Schedule.isDue(source, 60, now + 119999));
        verify(Schedule.isDue(source, 60, now + 120000));
        Schedule.complete(source, false, now + 120000);
        verify(!Schedule.isDue(source, 60, now + 359999));
        verify(Schedule.isDue(source, 60, now + 360000));
        Schedule.complete(source, true, now + 360000);
        compare(source.failCount, 0);
        compare(source.lastSync, now + 360000);
        verify(!Schedule.isDue(source, 60, now + 360001));
    }

    function test_backoffIsBoundedBySourceInterval() {
        var source = {
            syncInterval: 1,
            lastSync: 0,
            failCount: 100,
            lastAttempt: 10000000
        };
        verify(!Schedule.isDue(source, 60, 10059999));
        verify(Schedule.isDue(source, 60, 10060000));
        Schedule.complete(source, false, 10060000);
        compare(source.failCount, 5);
    }

    function test_invalidIntervalsUseBoundedDefault() {
        compare(Schedule.intervalMs({
            syncInterval: -1
        }, 60), 3600000);
        compare(Schedule.intervalMs({
            syncInterval: Infinity
        }, 60), 3600000);
        compare(Schedule.intervalMs({
            syncInterval: 99999999
        }, 60), 604800000);
    }
}
