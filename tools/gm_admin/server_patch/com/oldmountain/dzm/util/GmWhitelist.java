package com.oldmountain.dzm.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.oldmountain.dzm.DZM;

/**
 * [haizei] GM 白名单：与 PHP 运营后台共用 xml/TesterList.xml。
 * 老项目的 DZM.testerArray 只在启动时加载一次，后台改白名单后必须重启服务端；
 * 这里改为按文件修改时间热加载（最多每秒检查一次），后台改完即时生效。
 *
 * 登录时用它下发 isGM 标记，GM 指令处理时用它再次校验调用账号，
 * 避免只靠客户端开关或全局 CanUseGm 造成的越权。
 */
public final class GmWhitelist
{
    private static final Pattern TESTER = Pattern.compile(
        "<Tester\\s+puid=\"([^\"]*)\"", Pattern.CASE_INSENSITIVE);

    private static final Object LOCK = new Object();
    private static Set<String> cached = new HashSet<String>();
    private static long lastMtime = -1L;
    private static long lastCheck  = 0L;

    private GmWhitelist() {}

    public static boolean isGm(String puid)
    {
        if (puid == null || puid.length() == 0) return false;
        refreshIfNeeded();
        synchronized (LOCK) {
            return cached.contains(puid);
        }
    }

    private static void refreshIfNeeded()
    {
        long now = System.currentTimeMillis();
        if (lastMtime >= 0L && (now - lastCheck) < 1000L) return;
        lastCheck = now;
        try {
            File f = new File(DZM.basePath + "/xml/TesterList.xml");
            long m = f.lastModified();
            if (m == lastMtime) return;
            lastMtime = m;

            Set<String> next = new HashSet<String>();
            BufferedReader r = new BufferedReader(
                new InputStreamReader(new FileInputStream(f), "UTF-8"));
            try {
                String line;
                while ((line = r.readLine()) != null) {
                    Matcher mt = TESTER.matcher(line);
                    while (mt.find()) {
                        String p = mt.group(1).trim();
                        if (p.length() > 0) next.add(p);
                    }
                }
            } finally {
                r.close();
            }
            synchronized (LOCK) {
                cached = next;
            }
        } catch (Throwable t) {
            // 读失败时保留上一次的白名单，避免因临时 IO 问题把所有 GM 踢下线
        }
    }
}
