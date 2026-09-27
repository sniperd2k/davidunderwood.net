<%@ Page Language="C#" EnableViewState="false" AutoEventWireup="false" ResponseEncoding="utf-8" Culture="en-US" UICulture="en-US" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Collections.Generic" %>
<script runat="server">
  // Guestbook anti-bot: honeypot + signed math + time-trap + per-IP rate limit.
  // Storage: App_Data/guestbook.json   Rate: App_Data/ratelimit.json
  const string Secret = "ppc-4-life-not-a-password-just-hmac-pepper-v1";
  const int MinSeconds = 3;
  const int MaxSeconds = 1800;
  const int MaxPerHour = 3;
  const int MaxName = 40;
  const int MaxMsg = 280;
  const int MaxEntries = 200;

  string Flash = "";
  string FlashKind = "info";
  int MathA, MathB;
  string IssuedTicks = "";
  string Token = "";

  string DataPath { get { return Server.MapPath("~/App_Data/guestbook.json"); } }
  string RatePath { get { return Server.MapPath("~/App_Data/ratelimit.json"); } }

  string Hmac(string payload) {
    var key = Encoding.UTF8.GetBytes(Secret);
    using (var h = new System.Security.Cryptography.HMACSHA256(key)) {
      return BitConverter.ToString(h.ComputeHash(Encoding.UTF8.GetBytes(payload))).Replace("-", "").ToLowerInvariant();
    }
  }

  string JEscape(string s) {
    if (s == null) return "";
    return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
  }

  string H(string s) { return Server.HtmlEncode(s ?? ""); }

  void EnsureDataDir() {
    var dir = Server.MapPath("~/App_Data");
    if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
  }

  List<string[]> LoadEntries() {
    EnsureDataDir();
    var list = new List<string[]>();
    if (!File.Exists(DataPath)) {
      list.Add(new string[] { "SkiBum99", "Sick grab bro!!1!", "1999-02-14T12:00:00Z" });
      list.Add(new string[] { "PPC_Shredder", "See you on the park.", "2026-09-01T12:00:00Z" });
      list.Add(new string[] { "AASI_alum", "Teach the next generation.", "2026-09-15T12:00:00Z" });
      SaveEntries(list);
      return list;
    }
    var json = File.ReadAllText(DataPath);
    foreach (Match m in Regex.Matches(json, "\\{\\s*\"name\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*,\\s*\"message\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*,\\s*\"at\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"\\s*\\}")) {
      list.Add(new string[] { Unescape(m.Groups[1].Value), Unescape(m.Groups[2].Value), Unescape(m.Groups[3].Value) });
    }
    return list;
  }

  string Unescape(string s) {
    return s.Replace("\\n", "\n").Replace("\\r", "\r").Replace("\\t", "\t").Replace("\\\"", "\"").Replace("\\\\", "\\");
  }

  void SaveEntries(List<string[]> list) {
    EnsureDataDir();
    var sb = new StringBuilder();
    sb.Append("{\"entries\":[");
    for (int i = 0; i < list.Count; i++) {
      if (i > 0) sb.Append(",");
      sb.Append("{\"name\":\"").Append(JEscape(list[i][0])).Append("\",");
      sb.Append("\"message\":\"").Append(JEscape(list[i][1])).Append("\",");
      sb.Append("\"at\":\"").Append(JEscape(list[i][2])).Append("\"}");
    }
    sb.Append("]}");
    var tmp = DataPath + ".tmp";
    File.WriteAllText(tmp, sb.ToString(), Encoding.UTF8);
    if (File.Exists(DataPath)) File.Delete(DataPath);
    File.Move(tmp, DataPath);
  }

  bool RateLimitOk(string ip) {
    EnsureDataDir();
    var now = DateTime.UtcNow;
    var cutoff = now.AddHours(-1);
    var map = new Dictionary<string, List<DateTime>>(StringComparer.OrdinalIgnoreCase);
    if (File.Exists(RatePath)) {
      var raw = File.ReadAllText(RatePath);
      foreach (Match m in Regex.Matches(raw, "\"([^\"]+)\"\\s*:\\s*\\[([^\\]]*)\\]")) {
        var key = m.Groups[1].Value;
        var hits = new List<DateTime>();
        foreach (Match t in Regex.Matches(m.Groups[2].Value, "\"([^\"]+)\"")) {
          DateTime dt;
          if (DateTime.TryParse(t.Groups[1].Value, null, System.Globalization.DateTimeStyles.RoundtripKind, out dt) && dt >= cutoff)
            hits.Add(dt);
        }
        map[key] = hits;
      }
    }
    List<DateTime> mine;
    if (!map.TryGetValue(ip, out mine) || mine == null) mine = new List<DateTime>();
    if (mine.Count >= MaxPerHour) {
      WriteRate(map);
      return false;
    }
    mine.Add(now);
    map[ip] = mine;
    WriteRate(map);
    return true;
  }

  void WriteRate(Dictionary<string, List<DateTime>> map) {
    var sb = new StringBuilder();
    sb.Append("{\"ips\":{");
    bool first = true;
    foreach (var kv in map) {
      if (!first) sb.Append(",");
      first = false;
      sb.Append("\"").Append(JEscape(kv.Key)).Append("\":[");
      for (int i = 0; i < kv.Value.Count; i++) {
        if (i > 0) sb.Append(",");
        sb.Append("\"").Append(kv.Value[i].ToString("o")).Append("\"");
      }
      sb.Append("]");
    }
    sb.Append("}}");
    File.WriteAllText(RatePath, sb.ToString(), Encoding.UTF8);
  }

  void IssueChallenge() {
    var rnd = new Random(Guid.NewGuid().GetHashCode());
    MathA = rnd.Next(2, 9);
    MathB = rnd.Next(2, 9);
    IssuedTicks = DateTime.UtcNow.Ticks.ToString();
    Token = Hmac(IssuedTicks + "|" + (MathA + MathB).ToString());
  }

  string ClientIp() {
    var xff = Request.ServerVariables["HTTP_X_FORWARDED_FOR"];
    if (!string.IsNullOrEmpty(xff)) {
      var first = xff.Split(',')[0].Trim();
      if (first.Length > 0) return first;
    }
    return Request.UserHostAddress ?? "0.0.0.0";
  }

  string Sanitize(string s, int max) {
    if (s == null) return "";
    s = s.Trim();
    s = Regex.Replace(s, @"[\u0000-\u001F\u007F]", "");
    s = Regex.Replace(s, "<[^>]*>", "");
    if (s.Length > max) s = s.Substring(0, max);
    return s;
  }

  protected override void OnLoad(EventArgs e) {
    base.OnLoad(e);
    Response.Cache.SetCacheability(HttpCacheability.NoCache);
    if (string.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
      HandlePost();
    else
      IssueChallenge();
  }

  void HandlePost() {
    if (!string.IsNullOrEmpty(Request.Form["website"])) {
      Flash = "Thanks! (filtered)";
      FlashKind = "ok";
      IssueChallenge();
      return;
    }
    var ticks = Request.Form["issued"];
    var token = Request.Form["token"];
    long issuedLong;
    if (!long.TryParse(ticks, out issuedLong)) { Fail("Challenge expired. Reload and try again."); return; }
    var issued = new DateTime(issuedLong, DateTimeKind.Utc);
    var age = (DateTime.UtcNow - issued).TotalSeconds;
    if (age < MinSeconds) { Fail("Whoa shredder — too fast. Take a breath and retry."); return; }
    if (age > MaxSeconds) { Fail("Challenge expired. Reload the guestbook."); return; }

    int a, b, ans;
    if (!int.TryParse(Request.Form["math_a"], out a) ||
        !int.TryParse(Request.Form["math_b"], out b) ||
        !int.TryParse(Request.Form["math_answer"], out ans)) {
      Fail("Math check missing. Humans welcome — bots less so."); return;
    }
    var expect = Hmac(ticks + "|" + (a + b).ToString());
    if (!string.Equals(expect, token ?? "", StringComparison.OrdinalIgnoreCase) || ans != a + b) {
      Fail("Math check failed. Gravity is hard; addition should not be."); return;
    }

    var cname = Sanitize(Request.Form["guest_name"], MaxName);
    var cmsg = Sanitize(Request.Form["guest_msg"], MaxMsg);
    if (cname.Length < 2 || cmsg.Length < 2) { Fail("Name and message need a little more stoke (2+ chars)."); return; }

    if (!RateLimitOk(ClientIp())) {
      Fail("Rate limit: max " + MaxPerHour + " notes per hour. Hit the lift and come back.");
      return;
    }

    var store = LoadEntries();
    store.Insert(0, new string[] { cname, cmsg, DateTime.UtcNow.ToString("o") });
    while (store.Count > MaxEntries) store.RemoveAt(store.Count - 1);
    SaveEntries(store);
    Flash = "Signed! Welcome to the lodge guestbook.";
    FlashKind = "ok";
    IssueChallenge();
  }

  void Fail(string m) { Flash = m; FlashKind = "err"; IssueChallenge(); }
</script>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Guestbook — davidunderwood.net</title>
  <meta name="description" content="Sign the Pats Peak Crew guestbook — humans only." />
  <link rel="canonical" href="https://davidunderwood.net/guestbook.aspx" />
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-49HF3RFVKP"></script>
  <script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','G-49HF3RFVKP');</script>
  <link rel="stylesheet" href="assets/myspace.css" />
  <style>
    .flash-ok { background:#cfc; border:3px outset #0a0; color:#030; padding:8px; margin:8px 0; font-family:Tahoma,sans-serif; }
    .flash-err { background:#fcc; border:3px outset #a00; color:#400; padding:8px; margin:8px 0; font-family:Tahoma,sans-serif; }
    .hp { position:absolute; left:-10000px; top:auto; width:1px; height:1px; overflow:hidden; }
    label { display:block; font-family:Tahoma,sans-serif; font-weight:bold; margin-top:8px; color:#003; }
    input[type=text], textarea {
      width:100%; max-width:520px; font-size:16px; padding:8px; border:3px inset #808080;
      font-family:Tahoma,sans-serif; box-sizing:border-box;
    }
    textarea { min-height:90px; }
    .submit {
      margin-top:12px; min-height:44px; padding:8px 18px; font-weight:bold; font-size:1rem;
      background:linear-gradient(#ffff99,#ff9900); border:3px outset #fff; cursor:pointer;
    }
    .entry {
      background:#fff8dc; border:3px double #800000; padding:8px; margin:8px 0; color:#400;
      font-family:Georgia,serif;
    }
    .entry .who { font-weight:bold; color:#800080; }
    .entry .when { font-size:0.8rem; color:#666; }
    .anti { font-size:0.8rem; color:#444; font-family:Tahoma,sans-serif; margin-top:10px; }
  </style>
</head>
<body class="myspace">
  <a class="skip" href="#main">Skip to content</a>
  <div class="wrap">
    <marquee behavior="scroll" direction="left" scrollamount="5">★ GUESTBOOK ★ Sign it ★ PPC 4 LIFE ★ Bots will be yeeted off the chairlift ★</marquee>
    <div class="win95" id="main">
      <div class="titlebar"><span>📖 guestbook.aspx — Pats Peak Crew lodge book</span><span class="btns" aria-hidden="true"><span>_</span><span>□</span><span>×</span></span></div>
      <div class="panel-body">
        <div class="nav" role="navigation">
          <a href="./">🏠 Home</a>
          <a href="resume.html">📄 Resume</a>
          <a href="guestbook.aspx" aria-current="page">✍️ Guestbook</a>
        </div>

        <% if (!string.IsNullOrEmpty(Flash)) { %>
          <div class="flash-<%= FlashKind == "ok" ? "ok" : "err" %>" role="status"><%= H(Flash) %></div>
        <% } %>

        <div class="blurb">
          <h2>Sign the guestbook</h2>
          <p>Leave a note for the lodge. No phone numbers, no emails, no addresses — just vibes.</p>
          <form method="post" action="guestbook.aspx" id="gb-form" autocomplete="off">
            <div class="hp" aria-hidden="true">
              <label>Website<input type="text" name="website" tabindex="-1" value="" /></label>
            </div>
            <label for="guest_name">Handle / trail name</label>
            <input type="text" id="guest_name" name="guest_name" maxlength="40" required />
            <label for="guest_msg">Message</label>
            <textarea id="guest_msg" name="guest_msg" maxlength="280" required></textarea>
            <label for="math_answer">Anti-bot math: what is <%= MathA %> + <%= MathB %>?</label>
            <input type="text" id="math_answer" name="math_answer" inputmode="numeric" required />
            <input type="hidden" name="math_a" value="<%= MathA %>" />
            <input type="hidden" name="math_b" value="<%= MathB %>" />
            <input type="hidden" name="issued" value="<%= IssuedTicks %>" />
            <input type="hidden" name="token" value="<%= Token %>" />
            <button class="submit" type="submit">🏂 Sign guestbook</button>
          </form>
          <p class="anti">Spam controls: honeypot field, timed challenge (<%= MinSeconds %>s–<%= MaxSeconds/60 %>min), signed math token, <%= MaxPerHour %>/hour/IP rate limit. See <a href="GUESTBOOK.md">GUESTBOOK.md</a>.</p>
        </div>

        <div class="blurb" style="margin-top:12px;">
          <h2>Recent notes</h2>
          <% foreach (var en in LoadEntries()) { %>
            <div class="entry">
              <div><span class="who"><%= H(en[0]) %></span> <span class="when"><%= H(en[2]) %></span></div>
              <div><%= H(en[1]) %></div>
            </div>
          <% } %>
        </div>
      </div>
    </div>
    <p class="footer">© David Underwood · <a href="./">Home</a> · PPC 4 LIFE</p>
  </div>
  <script src="assets/myspace-audio.js"></script>
  <script>
    document.getElementById("gb-form").addEventListener("submit", function () {
      if (window.DUAudio) DUAudio.play("guestbook");
    });
  </script>
</body>
</html>
