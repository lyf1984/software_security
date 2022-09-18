import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:get/get.dart';
import 'package:software_security/ffi/u8_ptr_to_str.dart';
import 'generated_bindings.dart';
import 'dart:isolate';

final _receivePort = ReceivePort();

final RxString ffi_channel_str = RxString('');

final List<String> ffi_channel_str_list = [];
final StreamController<bool> _streamController = StreamController();
final Stream<bool> ffi_channel_str_list_notification = _streamController.stream;

const LIST_INCREASE = true;
const LIST_DECREASE = false;

ffilib _create() {
  final String libraryPath;
  if (GetPlatform.isMacOS) {
    libraryPath = 'libci.dylib';
  } else if (GetPlatform.isWindows) {
    libraryPath = 'ci.dll';
  } else {
    libraryPath = 'libci.so';
  }
  return ffilib(ffi.DynamicLibrary.open(libraryPath));
}

final ffilib _lib = _create();

void initFFIChannel(String path) {
  Isolate.spawn(_newIsolate, _iso_send_data_t(_receivePort.sendPort, path));
  _receivePort.listen((message) {
    final data = message as _internal_send_data_t;
    if (data.type == 1) {
      _streamController.sink.add(LIST_INCREASE);
      ffi_channel_str_list.add(data.str);
    } else {
      ffi_channel_str.value = data.str;
    }
  });
}

class _iso_send_data_t {
  const _iso_send_data_t(this.sendPort, this.path);

  final SendPort sendPort;

  final String path;
}

_iso_send_data_t? _iso_data;

void _newIsolate(_iso_send_data_t iso_data) {
  _iso_data = iso_data;
  ffi.Pointer<send_fn_t> fn = ffi.Pointer.fromFunction(_callback);
  final data = calloc.allocate<struct_attach_>(ffi.sizeOf<struct_attach_>());
  data.ref.executable_path = iso_data.path.toNativeUtf8().cast();
  data.ref.time = DateTime.now().millisecondsSinceEpoch;
  data.ref.send_fn = fn;
  _lib.ci_init(data);
  calloc.free(data);
}

class _internal_send_data_t {
  const _internal_send_data_t(this.type, this.str);

  final int type;

  final String str;
}

void _callback(send_data_t data) {
  final ffi.Pointer<ffi.Uint8> codeUnits = data.ref.str.cast();

  _iso_data?.sendPort
      .send(_internal_send_data_t(data.ref.type, codeUnits.string));
}
