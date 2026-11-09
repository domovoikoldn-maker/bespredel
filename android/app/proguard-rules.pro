# hev-socks5-tunnel регистрирует нативные методы по имени в JNI_OnLoad.
# Если R8 вырежет или переименует хоть один из них, библиотека не загрузится
# (NoClassDefFoundError: TProxyService). Сохраняем класс целиком.
-keep class com.domovoi4ik.bespredel.TProxyService { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}
