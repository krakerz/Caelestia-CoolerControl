#!/usr/bin/env python3
"""Print calendar events from ICS feeds, public holidays and Thunderbird as JSON for CalendarData.qml (named events.py to avoid shadowing the stdlib calendar module)."""

import configparser
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "caelestia-coolercontrol"
WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
MAX_SPAN_DAYS = 60
TB_ALLDAY = 8  # Thunderbird cal_events.flags bit for all-day events
TB_RID_ALLDAY = 512

# Google public-holiday calendar slugs by ISO country code; any other value is used as the slug verbatim.
GOOGLE_HOLIDAYS = {
    "AU": "australian", "AT": "austrian", "BR": "brazilian", "CA": "canadian", "CN": "china",
    "DK": "danish", "FI": "finnish", "FR": "french", "DE": "german", "GR": "greek",
    "HK": "hong_kong", "IN": "indian", "ID": "indonesian", "IE": "irish", "IL": "jewish",
    "IT": "italian", "JP": "japanese", "MY": "malaysia", "MX": "mexican", "NL": "dutch",
    "NZ": "new_zealand", "NO": "norwegian", "PH": "philippines", "PL": "polish", "PT": "portuguese",
    "RU": "russian", "SA": "saudiarabian", "SG": "singapore", "ZA": "sa", "KR": "south_korea",
    "ES": "spain", "SE": "swedish", "TW": "taiwan", "TR": "turkish", "GB": "uk", "UK": "uk",
    "US": "usa", "VN": "vietnamese",
}

errors = []


def local_tz():
    try:
        return ZoneInfo(os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1])
    except Exception:
        return dt.datetime.now().astimezone().tzinfo


LOCAL = local_tz()


def is_dt(x):
    return isinstance(x, dt.datetime)


def fetch(url, ttl, label):
    url = re.sub(r"^webcal://", "https://", url.strip())
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / ("dl-" + hashlib.sha1(url.encode()).hexdigest()[:16])
    if path.exists() and time.time() - path.stat().st_mtime < ttl:
        return path.read_text(encoding="utf-8", errors="replace")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "caelestia-coolercontrol"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            text = resp.read().decode("utf-8", errors="replace")
        path.write_text(text, encoding="utf-8")
        return text
    except Exception as e:
        # Only the host is reported: private calendar URLs embed a secret.
        errors.append(f"{label} ({urllib.parse.urlsplit(url).netloc}): {e}")
        return path.read_text(encoding="utf-8", errors="replace") if path.exists() else None


# --- ICS ---------------------------------------------------------------------

def parse_props(text):
    """Return VEVENTs as {NAME: [(params, value), ...]}, ignoring nested components like VALARM."""
    text = re.sub(r"\r?\n[ \t]", "", text)
    events, cur, depth = [], None, 0
    for line in text.splitlines():
        if line.startswith("BEGIN:"):
            if cur is None:
                if line.strip() == "BEGIN:VEVENT":
                    cur, depth = {}, 0
            else:
                depth += 1
            continue
        if line.startswith("END:"):
            if cur is not None:
                if depth == 0:
                    events.append(cur)
                    cur = None
                else:
                    depth -= 1
            continue
        if cur is None or depth or ":" not in line:
            continue
        head, _, value = line.partition(":")
        name, *params = head.split(";")
        pd = {}
        for p in params:
            k, _, v = p.partition("=")
            pd[k.upper()] = v.strip('"')
        cur.setdefault(name.upper(), []).append((pd, value))
    return events


def first(ev, name):
    return ev.get(name, [({}, "")])[0][1]


def unescape(s):
    return s.replace("\\n", " ").replace("\\N", " ").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\").strip()


def parse_time(value, params):
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return dt.datetime.strptime(value[:8], "%Y%m%d").date()
    stamp = dt.datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    if value.endswith("Z"):
        return stamp.replace(tzinfo=dt.timezone.utc).astimezone(LOCAL)
    tz = LOCAL
    if "TZID" in params:
        try:
            tz = ZoneInfo(params["TZID"])
        except Exception:
            pass  # e.g. Windows zone names; assume local
    return stamp.replace(tzinfo=tz).astimezone(LOCAL)


def parse_duration(v):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", v.strip())
    if not m:
        return None
    w, d, h, mi, s = (int(x or 0) for x in m.groups()[1:])
    td = dt.timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)
    return -td if m.group(1) == "-" else td


# --- Recurrence (RRULE subset: FREQ, INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY, BYMONTH) ---

def add_months(year, month, n):
    m = month - 1 + n
    return year + m // 12, m % 12 + 1


def month_days(year, month):
    start = dt.date(year, month, 1)
    ny, nm = add_months(year, month, 1)
    return [start + dt.timedelta(i) for i in range((dt.date(ny, nm, 1) - start).days)]


def pick_days(days, byday, bymonthday):
    by_wd = set()
    for spec in byday:
        m = re.fullmatch(r"([+-]?\d*)(MO|TU|WE|TH|FR|SA|SU)", spec)
        if not m:
            continue
        match = [d for d in days if d.weekday() == WEEKDAYS[m.group(2)]]
        if m.group(1) not in ("", "+", "-"):
            n = int(m.group(1))
            if n and -len(match) <= n <= len(match):
                by_wd.add(match[n - 1 if n > 0 else n])
        else:
            by_wd.update(match)
    by_md = {days[n - 1 if n > 0 else n] for n in bymonthday if n and -len(days) <= n <= len(days)}
    if byday and bymonthday:
        return sorted(by_wd & by_md)
    return sorted(by_wd if byday else by_md)


def expand(start, rule, exdates, win_start, win_end):
    """Yield occurrence starts (dates or aware datetimes) of an event, up to win_end."""
    if not rule:
        yield start
        return
    r = dict(p.split("=", 1) for p in rule.split(";") if "=" in p)
    freq = r.get("FREQ")
    interval = max(1, int(r.get("INTERVAL", 1)))
    count = int(r["COUNT"]) if "COUNT" in r else None
    until = None
    if "UNTIL" in r:
        until = parse_time(r["UNTIL"], {})
        if is_dt(start) and not is_dt(until):
            until = dt.datetime.combine(until, dt.time.max, LOCAL)
        elif not is_dt(start) and is_dt(until):
            until = until.date()
    byday = [s for s in r.get("BYDAY", "").split(",") if s]
    bymonthday = [int(x) for x in r.get("BYMONTHDAY", "").split(",") if x]
    bymonth = [int(x) for x in r.get("BYMONTH", "").split(",") if x]
    sday = start.date() if is_dt(start) else start

    # Without COUNT, jump close to the window instead of walking from a years-old DTSTART.
    k0 = 0
    gap = (win_start - sday).days - MAX_SPAN_DAYS
    if count is None and gap > 0:
        k0 = {"DAILY": gap // interval, "WEEKLY": gap // (7 * interval),
              "MONTHLY": gap // 31 // interval, "YEARLY": gap // 366 // interval}.get(freq, 0)

    n = 0
    for k in range(k0, k0 + 5000):
        if freq == "DAILY":
            period = sday + dt.timedelta(days=k * interval)
            days = [period] if not bymonth or period.month in bymonth else []
        elif freq == "WEEKLY":
            period = sday - dt.timedelta(days=sday.weekday()) + dt.timedelta(weeks=k * interval)
            days = sorted(period + dt.timedelta(WEEKDAYS[s[-2:]]) for s in byday if s[-2:] in WEEKDAYS) if byday \
                else [sday + dt.timedelta(weeks=k * interval)]
        elif freq == "MONTHLY":
            y, m = add_months(sday.year, sday.month, k * interval)
            period = dt.date(y, m, 1)
            md = month_days(y, m)
            days = pick_days(md, byday, bymonthday) if byday or bymonthday else [d for d in md if d.day == sday.day]
        elif freq == "YEARLY":
            y = sday.year + k * interval
            period = dt.date(y, 1, 1)
            days = []
            for m in bymonth or [sday.month]:
                md = month_days(y, m)
                days += pick_days(md, byday, bymonthday) if byday or bymonthday else [d for d in md if d.day == sday.day]
        else:
            yield start
            return
        if period > win_end:
            return
        for day in days:
            if day < sday:
                continue
            occ = dt.datetime.combine(day, start.timetz()) if is_dt(start) else day
            if until is not None and occ > until:
                return
            n += 1
            if count is not None and n > count:
                return
            if day > win_end:
                return
            if occ not in exdates:
                yield occ


# --- Output --------------------------------------------------------------------

def emit(out, title, start, end, all_day, source, color, holiday, win_start, win_end):
    base = {"title": title, "source": source, "color": color, "holiday": holiday, "allDay": all_day}
    if all_day:
        span = (end - start).days if end is not None and not is_dt(end) and end > start else 1
        for i in range(min(span, MAX_SPAN_DAYS)):
            d = start + dt.timedelta(i)
            if win_start <= d <= win_end:
                out.append({**base, "date": d.isoformat(), "start": "", "end": ""})
        return
    if end is None or end < start:
        end = start
    sd, ed = start.date(), end.date()
    if ed > sd and end == dt.datetime.combine(ed, dt.time(), LOCAL):
        ed -= dt.timedelta(1)  # ends exactly at midnight: don't show on the next day
    for i in range(min((ed - sd).days, MAX_SPAN_DAYS) + 1):
        d = sd + dt.timedelta(i)
        if win_start <= d <= win_end:
            out.append({**base, "date": d.isoformat(),
                        "start": start.strftime("%H:%M") if d == sd else "",
                        "end": end.strftime("%H:%M") if d == end.date() and end != start else ""})


def ics_occurrences(text, win_start, win_end, skip=None):
    """Yield (title, start, end, all_day) for every occurrence of every VEVENT in an ICS document."""
    events = parse_props(text)
    overridden = {}
    for ev in events:
        if "RECURRENCE-ID" in ev:
            p, v = ev["RECURRENCE-ID"][0]
            try:
                overridden.setdefault(first(ev, "UID"), set()).add(parse_time(v, p))
            except ValueError:
                pass
    for ev in events:
        if "DTSTART" not in ev or first(ev, "STATUS").upper() == "CANCELLED" or (skip and skip(ev)):
            continue
        try:
            p, v = ev["DTSTART"][0]
            start = parse_time(v, p)
            all_day = not is_dt(start)
            end = None
            if "DTEND" in ev:
                p, v = ev["DTEND"][0]
                end = parse_time(v, p)
            elif "DURATION" in ev:
                d = parse_duration(first(ev, "DURATION"))
                end = start + d if d else None
            if all_day and is_dt(end):
                end = end.date()
            elif not all_day and end is not None and not is_dt(end):
                end = dt.datetime.combine(end, dt.time(), LOCAL)
            length = end - start if end is not None else None
            rule = "" if "RECURRENCE-ID" in ev else first(ev, "RRULE")
            ex = set()
            for p, v in ev.get("EXDATE", []):
                for part in v.split(","):
                    try:
                        ex.add(parse_time(part, p))
                    except ValueError:
                        pass
            if rule:
                ex |= overridden.get(first(ev, "UID"), set())
        except ValueError:
            continue
        title = unescape(first(ev, "SUMMARY")) or "(untitled)"
        for occ in expand(start, rule, ex, win_start, win_end):
            yield title, occ, occ + length if length is not None else None, all_day


def ics_feeds(cfg, win_start, win_end, out):
    default_refresh = cfg.get("refreshMinutes", 30)
    for feed in cfg.get("ics", []):
        if not feed.get("enabled", True) or not feed.get("url"):
            continue
        name = feed.get("name", "Calendar")
        ttl = feed.get("refreshMinutes", default_refresh) * 60 - 30
        text = fetch(feed["url"], ttl, name)
        if not text:
            continue
        for title, s, e, a in ics_occurrences(text, win_start, win_end):
            emit(out, title, s, e, a, name, feed.get("color", ""), feed.get("holiday", False), win_start, win_end)


def holidays(cfg, win_start, win_end, out):
    hc = cfg.get("holidays", {})
    provider = hc.get("provider", "google")
    ttl = hc.get("refreshHours", 24 * 7) * 3600
    color = hc.get("color", "")
    for code in hc.get("countries", []):
        name = f"Holidays · {code.upper()}"
        if provider == "nager":
            for year in range(win_start.year, win_end.year + 1):
                text = fetch(f"https://date.nager.at/api/v3/PublicHolidays/{year}/{code.upper()}", ttl, name)
                try:
                    items = json.loads(text) if text else []
                except ValueError:
                    errors.append(f"{name}: unsupported country or bad response")
                    items = []
                for h in items:
                    title = h.get("localName") if hc.get("localNames") else h.get("name")
                    emit(out, title, dt.date.fromisoformat(h["date"]), None, True, name, color, True, win_start, win_end)
        else:
            slug = GOOGLE_HOLIDAYS.get(code.upper(), code)
            lang = hc.get("language", "en")
            url = f"https://calendar.google.com/calendar/ical/{lang}.{slug}%23holiday%40group.v.calendar.google.com/public/basic.ics"
            text = fetch(url, ttl, name)
            if not text:
                continue
            skip = None if hc.get("includeObservances", False) else \
                (lambda ev: "observance" in first(ev, "DESCRIPTION").lower())
            for title, s, e, a in ics_occurrences(text, win_start, win_end, skip):
                emit(out, title, s, e, a, name, color, True, win_start, win_end)


# --- Thunderbird -----------------------------------------------------------------

def thunderbird_profile(tb):
    if tb.get("profile", "auto") != "auto":
        return Path(os.path.expanduser(tb["profile"]))
    for root in (HOME / ".thunderbird", HOME / ".var/app/org.mozilla.Thunderbird/.thunderbird",
                 HOME / ".var/app/net.thunderbird.Thunderbird/.thunderbird"):
        ini = root / "profiles.ini"
        if not ini.exists():
            continue
        cp = configparser.ConfigParser(interpolation=None)
        cp.read(ini)
        paths = [cp[s]["Default"] for s in cp.sections() if s.startswith("Install") and "Default" in cp[s]]
        paths += [cp[s]["Path"] for s in cp.sections() if s.startswith("Profile") and cp[s].get("Default") == "1"]
        paths += [cp[s]["Path"] for s in cp.sections() if s.startswith("Profile") and "Path" in cp[s]]
        for p in paths:
            full = Path(p) if p.startswith("/") else root / p
            if (full / "calendar-data").is_dir():
                return full
    return None


def calendar_registry(profile):
    reg = {}
    try:
        text = (profile / "prefs.js").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return reg
    for cid, key, val in re.findall(r'user_pref\("calendar\.registry\.([^.]+)\.([^"]+)",\s*(.*?)\);', text):
        try:
            val = json.loads(val)
        except ValueError:
            pass
        reg.setdefault(cid, {})[key] = val
    return reg


def tb_time(us, tz, all_day):
    if us is None:
        return None
    if all_day or tz == "floating":
        naive = dt.datetime(1970, 1, 1) + dt.timedelta(microseconds=us)
        return naive.date() if all_day else naive.replace(tzinfo=LOCAL)
    return dt.datetime.fromtimestamp(us / 1e6, dt.timezone.utc).astimezone(LOCAL)


def tb_query(path):
    q_events = ("SELECT cal_id, id, title, flags, event_start, event_end, event_start_tz, event_end_tz, "
                "recurrence_id, recurrence_id_tz, ical_status FROM cal_events")
    q_rec = "SELECT cal_id, item_id, icalString FROM cal_recurrence"

    def run(p):
        con = sqlite3.connect(f"file:{p}?mode=ro", uri=True, timeout=2)
        try:
            return con.execute(q_events).fetchall(), con.execute(q_rec).fetchall()
        finally:
            con.close()

    try:
        return run(path)
    except sqlite3.Error:
        # Thunderbird may hold a lock; read a snapshot copy instead.
        CACHE.mkdir(parents=True, exist_ok=True)
        copy = CACHE / f"tb-{path.name}"
        for suffix in ("", "-wal"):
            src = Path(str(path) + suffix)
            if src.exists():
                shutil.copyfile(src, str(copy) + suffix)
        return run(copy)


def thunderbird(cfg, win_start, win_end, out):
    tb = cfg.get("thunderbird", {})
    if not tb.get("enabled", True):
        return
    profile = thunderbird_profile(tb)
    if not profile:
        errors.append("Thunderbird: no profile with calendars found")
        return
    wanted = tb.get("calendars", "all")
    colors = tb.get("colors", {})
    cals = {cid: c for cid, c in calendar_registry(profile).items()
            if not c.get("disabled") and (wanted == "all" or c.get("name") in wanted)}
    for db in ("local.sqlite", "cache.sqlite"):
        path = profile / "calendar-data" / db
        if not path.exists():
            continue
        try:
            rows, recs = tb_query(path)
        except (sqlite3.Error, OSError) as e:
            errors.append(f"Thunderbird {db}: {e}")
            continue
        rules, overridden = {}, {}
        for cal_id, item_id, ical in recs:
            entry = rules.setdefault((cal_id, item_id), {"rule": "", "ex": set()})
            for line in (ical or "").splitlines():
                head, _, value = line.partition(":")
                name, *params = head.split(";")
                pd = dict(p.split("=", 1) for p in params if "=" in p)
                if name == "RRULE":
                    entry["rule"] = value
                elif name == "EXDATE":
                    for part in value.split(","):
                        try:
                            entry["ex"].add(parse_time(part, pd))
                        except ValueError:
                            pass
        for cal_id, iid, _, flags, *_rest in rows:
            rid, rid_tz = _rest[4], _rest[5]
            if rid is not None:
                overridden.setdefault((cal_id, iid), set()).add(tb_time(rid, rid_tz, bool((flags or 0) & TB_RID_ALLDAY)))
        for cal_id, iid, title, flags, s, e, s_tz, e_tz, rid, _, status in rows:
            cal = cals.get(cal_id)
            if cal is None or (status or "").upper() == "CANCELLED" or s is None:
                continue
            all_day = bool((flags or 0) & TB_ALLDAY)
            start, end = tb_time(s, s_tz, all_day), tb_time(e, e_tz, all_day)
            rule, ex = "", set()
            if rid is None and (cal_id, iid) in rules:
                rule = rules[(cal_id, iid)]["rule"]
                ex = rules[(cal_id, iid)]["ex"] | overridden.get((cal_id, iid), set())
            length = end - start if end is not None else None
            name = cal.get("name", "Thunderbird")
            color = colors.get(name) or cal.get("color", "")
            for occ in expand(start, rule, ex, win_start, win_end):
                emit(out, title or "(untitled)", occ, occ + length if length is not None else None,
                     all_day, name, color, False, win_start, win_end)


def main():
    cfg_path = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "caelestia-coolercontrol/config.json"
    try:
        cfg = json.loads(cfg_path.read_text(encoding="utf-8")).get("calendar", {})
    except (OSError, ValueError) as e:
        print(json.dumps({"events": [], "errors": [f"config: {e}"]}))
        return
    today = dt.date.today()
    y, m = add_months(today.year, today.month, -int(cfg.get("monthsBack", 2)))
    win_start = dt.date(y, m, 1)
    y, m = add_months(today.year, today.month, int(cfg.get("monthsAhead", 12)) + 1)
    win_end = dt.date(y, m, 1) - dt.timedelta(1)

    out = []
    for label, source in (("Calendars", ics_feeds), ("Holidays", holidays), ("Thunderbird", thunderbird)):
        try:
            source(cfg, win_start, win_end, out)
        except Exception as e:
            errors.append(f"{label}: {e}")

    seen, events = set(), []
    for ev in sorted(out, key=lambda e: (e["date"], not e["allDay"], e["start"], e["title"])):
        k = (ev["date"], ev["title"], ev["start"])
        if k not in seen:
            seen.add(k)
            events.append(ev)
    print(json.dumps({"generated": dt.datetime.now(LOCAL).isoformat(timespec="seconds"),
                      "events": events, "errors": errors}))


if __name__ == "__main__":
    main()
