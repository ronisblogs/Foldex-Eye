import QtQuick 2.4
import QtQml.Models 2.2
import Material 0.2
import com.evercloud.rdp 0.1
import com.evercloud.conn 0.1
import com.evercloud.http 0.1

Page {
    id: desktop_selection

    backAction: Action {
        text: "返回"
        iconName: "navigation/arrow_back"
        onTriggered: desktop_selection.pop()
        visible: canGoBack
    }

    property bool heartbeat_error: false

    Component.onCompleted: {
        parse_info();
        heartbeat.startSending(UserConnection.token);
    }

    Component.onDestruction: {
        heartbeat.stop();
    }

    function parse_info() {
        console.log(UserConnection.info);
        var info = JSON.parse(UserConnection.info);
        UserConnection.token = info["token"];
        var vms = info["vms"];
        for (var vm_id in vms) {
            var detail = vms[vm_id];
            hosts.append({
                token: info["token"],
                vm_id: vm_id,
                name: detail["name"],
                host: detail["floating_ips"][0]});
        }
    }

    ListModel {
        id: hosts
    }

    Row {
        anchors.centerIn: parent
        spacing: 20

        Repeater {
            model: hosts

            delegate: Button {
                text: name;
                onClicked: {
                    UserConnection.currentHost = host;
                    UserConnection.currentVm = vm_id;
                    request.url = "http://192.168.1.41:8893/conn";
                    request.jsonData = JSON.stringify({ 'token': token, 'vm_id': vm_id });
                    request.sendJson();
                }
            }

        }
    }

    RDPProcess {
        id: rdp
        smoothFont: true
        dragFullWindow: true

        onErrorOccurred: {
            var err = rdp.errorCode();
            prompt.open("无法连接到桌面：" + err)
        }

        onFinished: {
            var code = rdp.status();
            if (code !== 0) {
                prompt.open("连接错误：" + rdp.status())
            }
            if (desktop_selection.heartbeat_error) { // 心跳异常，需要重新登录
                desktop_selection.pop();
            }

            heartbeat.startSending(UserConnection.token);
        }
    }

    Request {
        id: request
        onResponseChanged: {
            var code = request.code;
            var response = request.response;

            if (code === 200) {
                rdp.username = UserConnection.username;
                rdp.password = UserConnection.password;
                rdp.host = UserConnection.currentHost;
                rdp.start();
                heartbeat.startSending(UserConnection.token, UserConnection.currentVm);
            } else {
                prompt.open("无法启动虚拟机：" + response["err"])
            }

        }
    }

    HeartBeat {
        id: heartbeat
        url: "http://192.168.1.41:8893/heartbeat"
        onError: { // 心跳异常
            heartbeat.stop();
            desktop_selection.heartbeat_error = true;
        }
    }

    Snackbar {
        id: prompt
    }
}