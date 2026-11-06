<%@ WebHandler Language="C#" Class="AgentProbe" %>
using System;
using System.Linq;
using System.Web;
using Elastic.Apm;
public class AgentProbe : IHttpHandler {
  public bool IsReusable { get { return true; } }
  public void ProcessRequest(HttpContext ctx) {
    ctx.Response.ContentType = "text/plain";
    ctx.Response.Write("IsConfigured=" + Agent.IsConfigured + "\n");
    try { ctx.Response.Write("Enabled=" + Agent.Config.Enabled + "\n"); }
    catch (Exception ex) { ctx.Response.Write("EnabledErr=" + ex.Message + "\n"); }
    var tx = Agent.Tracer != null ? Agent.Tracer.CurrentTransaction : null;
    ctx.Response.Write("HasTx=" + (tx != null) + " TraceId=" + (tx != null ? tx.TraceId : "") + "\n");
    ctx.Response.Write("ApmLoc=" + typeof(Agent).Assembly.Location + "\n");
    ctx.Response.Write("ApmVer=" + typeof(Agent).Assembly.GetName().Version + "\n");
    var apms = AppDomain.CurrentDomain.GetAssemblies()
      .Where(a => a.GetName().Name == "Elastic.Apm")
      .Select(a => a.Location + " ver=" + a.GetName().Version)
      .ToArray();
    ctx.Response.Write("ElasticApmLoadCount=" + apms.Length + "\n");
    foreach (var line in apms) ctx.Response.Write("Loaded=" + line + "\n");
  }
}
