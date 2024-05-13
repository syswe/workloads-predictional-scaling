# Hooks

Hooks, Predictive Horizontal Pod Autoscaler'ın kullanıcı mantığını nasıl çağırması gerektiğini belirtir.

## http

HTTP hook, otomatik ölçeklendiricinin yapacağı bir HTTP isteğini tanımlamanıza olanak tanır. İstek hedefiyle ilgili bilgiler, HTTP parametreleri - `query` veya `body` parametreleri olarak sağlanır. Konfigürasyonda başarılı olarak tanımlanmayan bir durum kodu hatayı belirtir; böyle bir hata oluşursa, otomatik ölçeklendirici yanıt gövdesini yakalar ve kaydeder.

### Örnek

Bu, Holt Winters ile çalışma zamanı ayarlamalarını almak için http hook örnek konfigürasyonudur:

```yaml
holtWinters:
  runtimeTuningFetchHook:
    type: "http"
    timeout: 2500
    http:
      method: "GET"
      url: "https://www.jamiethompson.me"
      successCodes:
        - 200
      headers:
        exampleHeader: exampleHeaderValue
      parameterMode: query
```

Bu örneği açıklayalım:

- `type` = hook türü, bu örnekte `http` hook'tur.
- `timeout` = hook'un alabileceği maksimum süre milisaniye cinsindendir, bu
  örnekte `2500` (2.5 saniye), bu süreden daha uzun sürerse hook başarısız sayılacaktır.
- `http` = HTTP isteğinin konfigürasyonu.
  - `method` = HTTP isteğinin HTTP yöntemi.
  - `url` = HTTP isteğiyle hedeflenecek URL.
  - `successCodes` = isteğin başarılı olup olmadığını belirleyen başarı kodları listesi - bu listede olmayan bir kodla yanıt verilirse isteğin başarısız olduğu varsayılacaktır.
  - `headers` = istekle sağlanabilecek başlıkların sözlüğü, bu örnekte anahtar `exampleHeader` ve değer `exampleHeaderValue`dir. Bu isteğe bağlı bir parametredir.
  - `parameterMode` = parametreleri hedefe iletme modu; `query` - sorgu parametresi olarak veya `body` - gövde parametresi olarak. Bu örnekte sorgu parametresi olarak iletilir.

### POST Örneği

Bu, HTTP `POST` kullanarak ve bilgilerin gövde parametresi olarak iletildiği bir örnektir.

```yaml
runtimeTuningFetchHook:
  type: "http"
  timeout: 2500
  http:
    method: "POST"
    url: "https://www.jamiethompson.me"
    successCodes:
      - 200
      - 202
    parameterMode: body
```
