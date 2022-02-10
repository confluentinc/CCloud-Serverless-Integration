using Avro;
using Avro.Specific;
using Newtonsoft.Json;

namespace Io.Confluent.Developer.Avro;

public class UserTrade : ISpecificRecord
{
    public const string SchemaText = @"
    {
  ""fields"": [
    {
        ""default"": null,
        ""name"": ""REGIONID"",
        ""type"": [
        ""null"",
        ""string""
            ]
    },
    {
        ""default"": null,
        ""name"": ""QUANTITY"",
        ""type"": [
        ""null"",
        ""int""
            ]
    },
    {
        ""default"": null,
        ""name"": ""SYMBOL"",
        ""type"": [
        ""null"",
        ""string""
            ]
    },
    {
        ""default"": null,
        ""name"": ""PRICE"",
        ""type"": [
        ""null"",
        ""int""
            ]
    },
    {
        ""default"": null,
        ""name"": ""ACCOUNT"",
        ""type"": [
        ""null"",
        ""string""
            ]
    },
    {
        ""default"": null,
        ""name"": ""SIDE"",
        ""type"": [
        ""null"",
        ""string""
            ]
    }
    ],
""name"": ""KsqlDataSourceSchema"",
""namespace"": ""io.confluent.ksql.avro_schemas"",
""type"": ""record""
}";

    public static Schema _SCHEMA = Schema.Parse(SchemaText);
    [JsonIgnore] public virtual Schema Schema => _SCHEMA;
    public string RegionId { get; set; }
    public int Quantity { get; set; }
    public string Symbol { get; set; }
    public int Price { get; set; }
    public string Account { get; set; }
    public string Side { get; set; }
    
    public virtual object Get(int fieldPos)
    {
        switch (fieldPos)
        {
            case 0: return this.RegionId;
            case 1: return this.Quantity;
            case 2: return this.Price;
            case 3: return this.Account;
            case 4: return this.Side;
            default: throw new AvroRuntimeException("Bad index " + fieldPos + " in Get()");
        };
    }
   
    public virtual void Put(int fieldPos, object fieldValue)
    {
        switch (fieldPos)
        {
            case 0: this.RegionId = (string)fieldValue; break;
            case 1: this.Quantity = (int)fieldValue; break;
            case 2: this.Price = (int)fieldValue; break;
            case 3: this.Account = (string)fieldValue; break;
            case 4: this.Side = (string) fieldValue; break;
            default: throw new AvroRuntimeException("Bad index " + fieldPos + " in Put()");
        };
    }
    
}