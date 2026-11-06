using System;
using System.Threading.Tasks;
using Elastic.Apm;
using Elastic.Apm.Api;

namespace Contoso.Observability
{
    public sealed class ElasticApmTraceBackend : ITraceBackend
    {
        public IDisposable StartSpanOrTransaction(string name, string type, string subtype)
        {
            var tracer = Agent.Tracer;
            if (tracer == null) return Noop.Instance;

            var currentSpan = tracer.CurrentSpan;
            if (currentSpan != null)
            {
                var span = currentSpan.StartSpan(name, type, subtype);
                return new SpanScope(span);
            }

            var currentTx = tracer.CurrentTransaction;
            if (currentTx != null)
            {
                var span = currentTx.StartSpan(name, type, subtype);
                return new SpanScope(span);
            }

            var tx = tracer.StartTransaction(name, type);
            return new TransactionScope(tx);
        }

        public void CaptureException(Exception exception)
        {
            if (exception == null) return;
            var tracer = Agent.Tracer;
            if (tracer?.CurrentSpan != null)
            {
                tracer.CurrentSpan.CaptureException(exception);
                return;
            }
            if (tracer?.CurrentTransaction != null)
            {
                tracer.CurrentTransaction.CaptureException(exception);
                return;
            }
            tracer?.CaptureException(exception);
        }

        private sealed class SpanScope : IDisposable
        {
            private readonly ISpan _span;
            private bool _done;
            public SpanScope(ISpan span) { _span = span; }
            public void Dispose()
            {
                if (_done) return;
                _done = true;
                _span?.End();
            }
        }

        private sealed class TransactionScope : IDisposable
        {
            private readonly ITransaction _tx;
            private bool _done;
            public TransactionScope(ITransaction tx) { _tx = tx; }
            public void Dispose()
            {
                if (_done) return;
                _done = true;
                _tx?.End();
            }
        }

        private sealed class Noop : IDisposable
        {
            public static readonly Noop Instance = new Noop();
            public void Dispose() { }
        }
    }
}
