using System;
using System.Threading.Tasks;

namespace CleanSdkLib
{
    public class CleanService
    {
        public string Ping(string name) => "pong:" + (name ?? string.Empty);

        public async Task<string> PingAsync(string name)
        {
            await Task.Delay(1).ConfigureAwait(false);
            return "pong-async:" + (name ?? string.Empty);
        }

        public void Boom() => throw new InvalidOperationException("clean-boom");

        public int Value { get; set; } = 1;
    }
}
