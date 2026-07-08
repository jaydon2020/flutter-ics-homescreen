// gatt_bridge.cpp — GATT Characteristic1 and Descriptor1 async operations.

#include "gatt_bridge.h"

#include <atomic>
#include <memory>
#include <mutex>
#include <optional>
#include <utility>
#include <vector>

struct PendingProxy {
  std::shared_ptr<sdbus::IProxy> proxy;
  std::atomic_bool done{false};
};

static std::mutex pending_proxies_mutex;
static std::vector<std::shared_ptr<PendingProxy>> pending_proxies;

static void reap_done_proxies() {
  std::scoped_lock lock(pending_proxies_mutex);
  std::erase_if(pending_proxies, [](const auto& entry) {
    return entry->done.load(std::memory_order_acquire);
  });
}

static std::shared_ptr<PendingProxy> make_proxy(sdbus::IConnection& conn,
                                                const std::string& path) {
  reap_done_proxies();
  auto entry = std::make_shared<PendingProxy>();
  entry->proxy = std::shared_ptr<sdbus::IProxy>(
      sdbus::createProxy(conn, sdbus::ServiceName{"org.bluez"},
                         sdbus::ObjectPath{path})
          .release());
  std::scoped_lock lock(pending_proxies_mutex);
  pending_proxies.push_back(entry);
  return entry;
}

// ═══════════════════════════════════════════════════════════════════════════
// GattCharBridge
// ═══════════════════════════════════════════════════════════════════════════

void GattCharBridge::read_value_async(sdbus::IConnection& conn,
                                      const std::string& char_path,
                                      Dart_Port_DL result_port) {
  auto pending = make_proxy(conn, char_path);
  std::map<std::string, sdbus::Variant> options;

  pending->proxy->callMethodAsync("ReadValue")
      .onInterface(kGattCharIface)
      .withArguments(options)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        char_path,
                        result_port](std::optional<sdbus::Error> error,
                                     const std::vector<uint8_t>& value) {
        if (error) {
          post_error(result_port, char_path, error->getName(),
                     error->getMessage());
        } else {
          post_value_result(result_port, char_path, value);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

void GattCharBridge::write_value_async(sdbus::IConnection& conn,
                                       const std::string& char_path,
                                       const uint8_t* data,
                                       int32_t len,
                                       bool with_response,
                                       Dart_Port_DL result_port) {
  if (len < 0 || data == nullptr) {
    post_error(result_port, char_path, "org.bluez.Error.InvalidArguments",
               "Invalid write data");
    return;
  }
  // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
  std::vector<uint8_t> value(data, data + static_cast<size_t>(len));
  auto pending = make_proxy(conn, char_path);
  std::map<std::string, sdbus::Variant> options;
  if (!with_response) {
    options["type"] = sdbus::Variant{std::string{"command"}};
  }

  pending->proxy->callMethodAsync("WriteValue")
      .onInterface(kGattCharIface)
      .withArguments(value, options)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        char_path,
                        result_port](std::optional<sdbus::Error> error) {
        if (error) {
          post_error(result_port, char_path, error->getName(),
                     error->getMessage());
        } else {
          post_success(result_port);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

void GattCharBridge::start_notify_async(sdbus::IConnection& conn,
                                        const std::string& char_path,
                                        ObjectManager& obj_mgr,
                                        Dart_Port_DL result_port) {
  auto pending = make_proxy(conn, char_path);

  pending->proxy->callMethodAsync("StartNotify")
      .onInterface(kGattCharIface)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        char_path, &obj_mgr,
                        result_port](std::optional<sdbus::Error> error) {
        if (error) {
          post_error(result_port, char_path, error->getName(),
                     error->getMessage());
        } else {
          obj_mgr.subscribe_char_notify(char_path);
          post_success(result_port);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

void GattCharBridge::stop_notify_async(sdbus::IConnection& conn,
                                       const std::string& char_path,
                                       ObjectManager& obj_mgr,
                                       Dart_Port_DL result_port) {
  auto pending = make_proxy(conn, char_path);

  pending->proxy->callMethodAsync("StopNotify")
      .onInterface(kGattCharIface)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        char_path, &obj_mgr,
                        result_port](std::optional<sdbus::Error> error) {
        if (error) {
          post_error(result_port, char_path, error->getName(),
                     error->getMessage());
        } else {
          obj_mgr.unsubscribe_char_notify(char_path);
          post_success(result_port);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

// ── Dart posting helpers ────────────────────────────────────────────────────

void GattCharBridge::post_success(Dart_Port_DL result_port) {
  uint8_t sentinel = 0xFF;
  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = 1;
  obj.value.as_typed_data.values = &sentinel;
  Dart_PostCObject_DL(result_port, &obj);
}

void GattCharBridge::post_value_result(Dart_Port_DL result_port,
                                       const std::string& object_path,
                                       const std::vector<uint8_t>& value) {
  BlueZValueResult result;
  result.objectPath = object_path;
  result.value = value;

  auto payload = glz::encode(result);

  std::vector<uint8_t> buf;
  buf.reserve(1 + payload.size());
  buf.push_back(0x10);
  buf.insert(buf.end(), payload.begin(), payload.end());

  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
  obj.value.as_typed_data.values = buf.data();
  Dart_PostCObject_DL(result_port, &obj);
}

void GattCharBridge::post_error(Dart_Port_DL result_port,
                                const std::string& object_path,
                                const std::string& error_name,
                                const std::string& error_message) {
  BlueZError err;
  err.objectPath = object_path;
  err.name = error_name;
  err.message = error_message;

  auto payload = glz::encode(err);

  std::vector<uint8_t> buf;
  buf.reserve(1 + payload.size());
  buf.push_back(0x20);
  buf.insert(buf.end(), payload.begin(), payload.end());

  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
  obj.value.as_typed_data.values = buf.data();
  Dart_PostCObject_DL(result_port, &obj);
}

// ═══════════════════════════════════════════════════════════════════════════
// GattDescBridge
// ═══════════════════════════════════════════════════════════════════════════

void GattDescBridge::read_value_async(sdbus::IConnection& conn,
                                      const std::string& desc_path,
                                      Dart_Port_DL result_port) {
  auto pending = make_proxy(conn, desc_path);
  std::map<std::string, sdbus::Variant> options;

  pending->proxy->callMethodAsync("ReadValue")
      .onInterface(kGattDescIface)
      .withArguments(options)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        desc_path,
                        result_port](std::optional<sdbus::Error> error,
                                     const std::vector<uint8_t>& value) {
        if (error) {
          post_error(result_port, desc_path, error->getName(),
                     error->getMessage());
        } else {
          post_value_result(result_port, desc_path, value);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

void GattDescBridge::write_value_async(sdbus::IConnection& conn,
                                       const std::string& desc_path,
                                       const uint8_t* data,
                                       int32_t len,
                                       Dart_Port_DL result_port) {
  if (len < 0 || data == nullptr) {
    post_error(result_port, desc_path, "org.bluez.Error.InvalidArguments",
               "Invalid write data");
    return;
  }
  // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
  std::vector<uint8_t> value(data, data + static_cast<size_t>(len));
  auto pending = make_proxy(conn, desc_path);
  std::map<std::string, sdbus::Variant> options;

  pending->proxy->callMethodAsync("WriteValue")
      .onInterface(kGattDescIface)
      .withArguments(value, options)
      .uponReplyInvoke([pending = std::weak_ptr<PendingProxy>(pending),
                        desc_path,
                        result_port](std::optional<sdbus::Error> error) {
        if (error) {
          post_error(result_port, desc_path, error->getName(),
                     error->getMessage());
        } else {
          post_success(result_port);
        }
        if (auto entry = pending.lock()) {
          entry->done.store(true, std::memory_order_release);
        }
      });
}

// ── Dart posting helpers ────────────────────────────────────────────────────

void GattDescBridge::post_success(Dart_Port_DL result_port) {
  uint8_t sentinel = 0xFF;
  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = 1;
  obj.value.as_typed_data.values = &sentinel;
  Dart_PostCObject_DL(result_port, &obj);
}

void GattDescBridge::post_value_result(Dart_Port_DL result_port,
                                       const std::string& object_path,
                                       const std::vector<uint8_t>& value) {
  BlueZValueResult result;
  result.objectPath = object_path;
  result.value = value;

  auto payload = glz::encode(result);

  std::vector<uint8_t> buf;
  buf.reserve(1 + payload.size());
  buf.push_back(0x11);
  buf.insert(buf.end(), payload.begin(), payload.end());

  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
  obj.value.as_typed_data.values = buf.data();
  Dart_PostCObject_DL(result_port, &obj);
}

void GattDescBridge::post_error(Dart_Port_DL result_port,
                                const std::string& object_path,
                                const std::string& error_name,
                                const std::string& error_message) {
  BlueZError err;
  err.objectPath = object_path;
  err.name = error_name;
  err.message = error_message;

  auto payload = glz::encode(err);

  std::vector<uint8_t> buf;
  buf.reserve(1 + payload.size());
  buf.push_back(0x20);
  buf.insert(buf.end(), payload.begin(), payload.end());

  Dart_CObject obj;
  obj.type = Dart_CObject_kTypedData;
  obj.value.as_typed_data.type = Dart_TypedData_kUint8;
  obj.value.as_typed_data.length = static_cast<intptr_t>(buf.size());
  obj.value.as_typed_data.values = buf.data();
  Dart_PostCObject_DL(result_port, &obj);
}
