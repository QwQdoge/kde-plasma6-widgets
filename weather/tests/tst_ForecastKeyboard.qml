import QtQuick
import QtTest
import "../contents/ui"

TestCase {
    id: testRoot
    name: "ForecastKeyboard"
    when: windowShown
    width: 400
    height: 300

    Component {
        id: forecastFactory
        ForecastItem {
            width: 100
            height: 120
            label: "Monday"
            iconPath: ""
            temp: 20
            isHourly: false
            itemIndex: 2
            forecastData: ({
                    hasDetails: true
                })
        }
    }

    SignalSpy {
        id: clicks
        signalName: "clicked"
    }

    function test_keyboardOpensCurrentForecastExactlyOnce() {
        var card = createTemporaryObject(forecastFactory, testRoot);
        verify(card !== null);
        clicks.target = card;
        clicks.clear();
        card.forceActiveFocus();
        tryCompare(card, "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(clicks.count, 1);
        compare(clicks.signalArguments[0][1], 2);
        compare(clicks.signalArguments[0][2].width, 100);
        compare(clicks.signalArguments[0][2].height, 120);
        clicks.clear();
        keyClick(Qt.Key_Return);
        compare(clicks.count, 1);
    }

    function test_missingDetailsCannotActivateOrJoinTabChain() {
        var card = createTemporaryObject(forecastFactory, testRoot);
        clicks.target = card;
        clicks.clear();
        card.forecastData = null;
        compare(card.activeFocusOnTab, false);
        card.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(clicks.count, 0);
        compare(card.activateForecast(), false);
        compare(clicks.count, 0);
        card.forecastData = {
            hasDetails: true
        };
        compare(card.activeFocusOnTab, true);
        verify(card.activateForecast());
        compare(clicks.count, 1);
    }
}
