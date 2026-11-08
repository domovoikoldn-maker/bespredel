package com.domovoi4ik.bespredel;

/**
 * JNI-мост к hev-socks5-tunnel (libhev-socks5-tunnel.so).
 * Библиотека собирается с -DPKGNAME=com/domovoi4ik/bespredel -DCLSNAME=TProxyService
 * и регистрирует методы на этом классе (сигнатуры — как в README hev-socks5-tunnel).
 */
public final class TProxyService {
    static {
        System.loadLibrary("hev-socks5-tunnel");
    }

    private TProxyService() {}

    public static native boolean TProxyStartService(String configPath, int fd);

    public static native boolean TProxyStopService();

    public static native boolean TProxyIsRunning();

    public static native long[] TProxyGetStats();
}
