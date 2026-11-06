using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;

namespace Contoso.Shipments.Business
{
    public class ShipmentRepository
    {
        private readonly string _connectionString;

        public ShipmentRepository()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["ContosoShipments"]?.ConnectionString
                ?? @"Server=.\SQLEXPRESS;Database=ContosoShipments;Integrated Security=True;Connection Timeout=5";
        }

        public ShipmentRepository(string connectionString)
        {
            _connectionString = connectionString;
        }

        public DataTable GetShipment(string trackingId)
        {
            EnsureSchema();
            using (var conn = new SqlConnection(_connectionString))
            using (var cmd = new SqlCommand(
                "SELECT TrackingId, Lane, WeightKg, Status, CreatedUtc FROM Shipments WHERE TrackingId = @id", conn))
            {
                cmd.Parameters.AddWithValue("@id", trackingId ?? string.Empty);
                var table = new DataTable();
                try
                {
                    conn.Open();
                    using (var reader = cmd.ExecuteReader())
                    {
                        table.Load(reader);
                    }
                }
                catch (SqlException)
                {
                    // Synthetic lab: return empty when SQL is unavailable
                }
                return table;
            }
        }

        /// <summary>Deliberate slow query using WAITFOR DELAY for APM dependency demos.</summary>
        public void RunSlowQuery(int delaySeconds = 2)
        {
            EnsureSchema();
            // Use a string literal for WAITFOR DELAY — SqlDbType.Time params are unreliable here.
            var seconds = Math.Max(1, Math.Min(delaySeconds, 10));
            var sql = string.Format("WAITFOR DELAY '00:00:{0:D2}'; SELECT 1 AS Ok;", seconds);
            using (var conn = new SqlConnection(_connectionString))
            using (var cmd = new SqlCommand(sql, conn))
            {
                try
                {
                    conn.Open();
                    cmd.ExecuteScalar();
                }
                catch (SqlException)
                {
                    // Swallow when Express not ready; still useful for HTTP path testing
                }
            }
        }

        public async Task RunSlowQueryAsync(int delaySeconds = 2)
        {
            await Task.Run(() => RunSlowQuery(delaySeconds)).ConfigureAwait(false);
        }

        public void UpsertSample(string trackingId, string lane, int weightKg)
        {
            EnsureSchema();
            using (var conn = new SqlConnection(_connectionString))
            using (var cmd = new SqlCommand(@"
IF NOT EXISTS (SELECT 1 FROM Shipments WHERE TrackingId = @id)
  INSERT INTO Shipments(TrackingId, Lane, WeightKg, Status, CreatedUtc) VALUES (@id, @lane, @w, 'Created', SYSUTCDATETIME());
ELSE
  UPDATE Shipments SET Lane=@lane, WeightKg=@w WHERE TrackingId=@id;", conn))
            {
                cmd.Parameters.AddWithValue("@id", trackingId);
                cmd.Parameters.AddWithValue("@lane", lane);
                cmd.Parameters.AddWithValue("@w", weightKg);
                try
                {
                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
                catch (SqlException)
                {
                }
            }
        }

        private void EnsureSchema()
        {
            using (var conn = new SqlConnection(_connectionString))
            using (var cmd = new SqlCommand(@"
IF OBJECT_ID('dbo.Shipments') IS NULL
BEGIN
  CREATE TABLE dbo.Shipments (
    TrackingId NVARCHAR(64) NOT NULL PRIMARY KEY,
    Lane NVARCHAR(64) NOT NULL,
    WeightKg INT NOT NULL,
    Status NVARCHAR(32) NOT NULL,
    CreatedUtc DATETIME2 NOT NULL
  );
END", conn))
            {
                try
                {
                    conn.Open();
                    cmd.ExecuteNonQuery();
                }
                catch (SqlException)
                {
                }
            }
        }
    }
}
