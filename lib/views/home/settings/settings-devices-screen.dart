import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:syphon/domain/auth/actions.dart';
import 'package:syphon/domain/index.dart';
import 'package:syphon/domain/settings/actions.dart';
import 'package:syphon/domain/settings/devices-settings/model.dart';
import 'package:syphon/global/colors.dart';
import 'package:syphon/global/dimensions.dart';
import 'package:syphon/global/strings.dart';
import 'package:syphon/views/widgets/appbars/appbar-normal.dart';
import 'package:syphon/views/widgets/dialogs/dialog-confirm-password.dart';
import 'package:syphon/views/widgets/dialogs/dialog-text-input.dart';
import 'package:syphon/views/widgets/lifecycle.dart';
import 'package:syphon/views/widgets/loader/index.dart';

class DevicesScreen extends StatefulWidget {
  @override
  DeviceViewState createState() => DeviceViewState();
}

class DeviceViewState extends State<DevicesScreen> with Lifecycle<DevicesScreen> {
  bool deleting = false;
  List<Device>? selectedDevices;

  @override
  onMounted() {
    final store = StoreProvider.of<AppState>(context);

    store.dispatch(fetchDevices());
  }

  onDismissDeviceOptions() {
    setState(() {
      selectedDevices = null;
    });
  }

  onToggleAllDevices({required List<Device> devices}) {
    var newSelectedDevices = selectedDevices ?? <Device>[];

    if (newSelectedDevices.length == devices.length) {
      newSelectedDevices = [];
    } else {
      newSelectedDevices = devices;
    }

    setState(() {
      selectedDevices = newSelectedDevices;
    });
  }

  onToggleModifyDevice({required Device device}) {
    final newSelectedDevices = selectedDevices ?? <Device>[];

    if (newSelectedDevices.contains(device)) {
      newSelectedDevices.remove(device);
    } else {
      newSelectedDevices.add(device);
    }

    setState(() {
      selectedDevices = newSelectedDevices;
    });
  }

  onDeleteDevices(BuildContext context, List<Device> devices, _Props props) async {
    final store = StoreProvider.of<AppState>(context);

    if (devices.isEmpty) return;

    final List<String?> deviceIds = devices.map((device) => device.deviceId).toList();

    await store.dispatch(deleteDevices(deviceIds: deviceIds));

    final authSession = store.state.authStore.authSession;

    if (authSession == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => DialogConfirmPassword(
        title: Strings.titleConfirmPassword,
        content: Strings.contentDeleteDevices,
        checkLoading: () => store.state.settingsStore.loading,
        checkValid: () => store.state.authStore.credential?.value?.isNotEmpty ?? false,
        onChangePassword: (password) {
          store.dispatch(updateCredential(value: password));
        },
        onConfirm: () async {
          final List<String?> deviceIds = devices.map((device) => device.deviceId).toList();

          await store.dispatch(deleteDevices(deviceIds: deviceIds));

          store.dispatch(resetInteractiveAuth());
          Navigator.of(dialogContext).pop();
        },
        onCancel: () async {
          store.dispatch(resetInteractiveAuth());
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Widget buildDeviceOptionsBar(BuildContext context, _Props props) {
    var selfSelectedDevice;

    if (selectedDevices != null) {
      selfSelectedDevice = selectedDevices!.indexWhere(
        (device) => device.deviceId == props.currentDeviceId,
      );
    }

    return AppBar(
      systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
      backgroundColor: Color(AppColors.greyDefault),
      automaticallyImplyLeading: false,
      titleSpacing: 0.0,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(left: 8),
            child: IconButton(
              icon: Icon(Icons.close),
              color: Colors.white,
              iconSize: Dimensions.buttonAppBarSize,
              onPressed: onDismissDeviceOptions,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.edit),
          iconSize: Dimensions.buttonAppBarSize,
          tooltip: 'Rename Device',
          color: Colors.white,
          onPressed:
              selectedDevices!.length != 1 ? null : () => props.onRenameDevice(context, selectedDevices![0]),
        ),
        IconButton(
          icon: Icon(Icons.delete),
          iconSize: Dimensions.buttonAppBarSize,
          tooltip: 'Delete Device',
          color: Colors.white,
          onPressed:
              selfSelectedDevice != -1 ? null : () => onDeleteDevices(context, selectedDevices ?? [], props),
        ),
        IconButton(
          icon: Icon(Icons.select_all),
          iconSize: Dimensions.buttonAppBarSize,
          tooltip: 'Select All',
          color: Colors.white,
          onPressed: () => onToggleAllDevices(devices: props.devices),
        ),
      ],
    );
  }

  Widget buildAppBar({BuildContext? context, _Props? props}) {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context!, false),
      ),
      title: Text(
        Strings.titleDevices,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w100,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext original) => StoreConnector<AppState, _Props>(
        distinct: true,
        converter: (Store<AppState> store) => _Props.mapStateToProps(store),
        builder: (context, props) {
          final sectionBackgroundColor = Theme.of(context).brightness == Brightness.dark
              ? const Color(AppColors.blackDefault)
              : const Color(AppColors.whiteDefault);

          Widget currentAppBar = AppBarNormal(title: Strings.titleDevices);

          if (selectedDevices != null) {
            currentAppBar = buildDeviceOptionsBar(context, props);
          }

          return Scaffold(
            appBar: currentAppBar as PreferredSizeWidget?,
            body: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Stack(
                children: [
                  GridView.builder(
                    primary: true,
                    shrinkWrap: true,
                    itemCount: props.devices.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final device = props.devices[index];

                      Color? iconColor;
                      Color? backgroundColor;
                      IconData deviceTypeIcon = Icons.phone_android;
                      TextStyle textStyle = Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12);
                      final bool isCurrentDevice = props.currentDeviceId == device.deviceId;

                      if (device.displayName!.contains('Firefox') || device.displayName!.contains('Mac')) {
                        deviceTypeIcon = Icons.laptop;
                      } else if (device.displayName!.contains('iOS')) {
                        deviceTypeIcon = Icons.phone_iphone;
                      }

                      if (selectedDevices != null && selectedDevices!.contains(device)) {
                        backgroundColor = AppColors.hashedColor(device.deviceId);
                        backgroundColor = Color(AppColors.greyDefault);
                        textStyle = textStyle.copyWith(color: Colors.white);
                        iconColor = Colors.white;
                      }

                      return InkWell(
                        onTap: selectedDevices == null ? null : () => onToggleModifyDevice(device: device),
                        onLongPress: () => onToggleModifyDevice(device: device),
                        child: Card(
                          elevation: 0,
                          color: backgroundColor ?? sectionBackgroundColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Stack(
                                children: <Widget>[
                                  Container(
                                    padding: EdgeInsets.only(bottom: 8, top: 8),
                                    child: Icon(
                                      deviceTypeIcon,
                                      size: Dimensions.iconSize * 1.5,
                                      color: iconColor,
                                    ),
                                  ),
                                  Visibility(
                                    visible: isCurrentDevice,
                                    child: Positioned(
                                      right: 0,
                                      bottom: 4,
                                      child: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: Colors.cyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: <Widget>[
                                  Text(
                                    device.displayName!,
                                    textAlign: TextAlign.center,
                                    style: textStyle,
                                  ),
                                  Text(
                                    device.deviceId!,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    child: Loader(
                      loading: props.loading,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _Props extends Equatable {
  final bool valid;
  final bool loading;
  final List<Device> devices;
  final String? currentDeviceId;

  final Function onFetchDevices;
  final Function onRenameDevice;

  const _Props({
    required this.valid,
    required this.loading,
    required this.devices,
    required this.currentDeviceId,
    required this.onFetchDevices,
    required this.onRenameDevice,
  });

  @override
  List<Object> get props => [
        valid,
        loading,
        devices,
      ];

  static _Props mapStateToProps(Store<AppState> store) => _Props(
        valid: store.state.authStore.credential != null &&
            store.state.authStore.credential!.value != null &&
            store.state.authStore.credential!.value!.isNotEmpty,
        loading: store.state.settingsStore.loading,
        devices: store.state.settingsStore.devices,
        currentDeviceId: store.state.authStore.user.deviceId,
        onFetchDevices: () => store.dispatch(fetchDevices()),
        onRenameDevice: (BuildContext context, Device device) async {
          showDialog(
            context: context,
            builder: (dialogContext) => DialogTextInput(
              title: Strings.titleRenameDevice,
              content: Strings.contentRenameDevice,
              randomizeText: true,
              label: device.displayName ?? '',
              onConfirm: (String newDisplayName) async {
                await store.dispatch(renameDevice(deviceId: device.deviceId, displayName: newDisplayName));
                store.dispatch(resetInteractiveAuth());
                Navigator.of(dialogContext).pop();
              },
              onCancel: () async {
                store.dispatch(resetInteractiveAuth());
                Navigator.of(dialogContext).pop();
              },
            ),
          );
        },
      );
}
