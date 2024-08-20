# 🛡️ UFW AbuseIPDB Reporter
Narzędzie, które analizuje logi firewalla UFW i zgłasza złośliwe adresy IP do bazy danych [AbuseIPDB](https://www.abuseipdb.com).

Pamiętaj! Jeśli planujesz wprowadzić zmiany w którymkolwiek z plików tego repozytorium, utwórz najpierw jego publiczny fork.

[[Polish](README_PL.md)] | [[English](README.md)]

- [⚙️ Jak to dokładniej działa?](#jak-to-dziala)
- [📋 Wymagania](#wymagania)
- [🛠️ Instalacja wymaganych pakietów](#instalacja-wymaganych-pakietow)
  - [Wykonaj aktualizacje repozytoriów i oprogramowania (wysoko zalecane)](#wykonaj-aktualizacje-repozytoriow)
  - [Zainstaluj wymagane zależności](#zainstaluj-wymagane-zaleznosci)
- [🧪 Testowane systemy operacyjne](#testowane-systemy-operacyjne)
- [🚀 Instalacja](#instalacja)
- [🖥️ Użycie](#uzycie)
- [🔍 Sprawdzenie statusu usługi](#sprawdzenie-statusu-uslugi)
- [📄 Przykładowe zgłoszenie](#przykladowe-zgloszenie)
- [🤝 Pull requesty](#pull-requesty)
- [🔑 Licencja MIT](#licencja-mit)

## ⚙️ Jak to dokładniej działa?<div id="jak-to-dziala"></div>
1. **Monitorowanie logów UFW:** Narzędzie stale śledzi logi generowane przez firewall UFW, poszukując prób nieautoryzowanego dostępu lub innych podejrzanych działań.
2. **Analiza zgłoszonego adresu:** Po zidentyfikowaniu podejrzanego adresu IP, skrypt sprawdza, czy adres ten został już wcześniej zgłoszony.
3. **Zgłaszanie IP do AbuseIPDB:** Jeśli IP spełnia kryteria, adres jest zgłaszany do bazy danych AbuseIPDB wraz z informacjami o protokole, porcie źródłowym i docelowym itd.
4. **Cache zgłoszonych IP:** Narzędzie przechowuje listę zgłoszonych IP w pliku tymczasowym, aby zapobiec wielokrotnemu zgłaszaniu tego samego adresu IP w krótkim czasie.

## 📋 Wymagania<div id="wymagania"></div>
- **System operacyjny:** Linux z zainstalowanym i skonfigurowanym firewallem UFW.
- **Konto AbuseIPDB:** Wymagane jest konto w serwisie AbuseIPDB [z ważnym tokenem API](https://www.abuseipdb.com/account/api). Token API jest niezbędny.
- **Zainstalowane pakiety:**
  - `wget` lub `curl`: Jedno z tych narzędzi jest wymagane do pobrania skryptu instalacyjnego z repozytorium GitHub oraz do wysyłania zapytań do API AbuseIPDB.
  - `jq`: Narzędzie do przetwarzania i parsowania danych w formacie JSON, zwracanych przez API AbuseIPDB.
  - `openssl`: Używane do kodowania i dekodowania tokena API, aby zabezpieczyć dane uwierzytelniające.
  - `awk`, `grep`, `sed`: Standardowe narzędzia Unixowe wykorzystywane do przetwarzania tekstu i analizy logów.
- **Połączenie z Internetem:** Hm, wydaje, mi się, że jest to oczywiste, prawda?

### 🛠️ Instalacja wymaganych pakietów<div id="instalacja-wymaganych-pakietow"></div>
#### Wykonaj aktualizacje repozytoriów i oprogramowania (wysoko zalecane)
```bash
sudo apt update && sudo apt upgrade -y
```

#### Zainstaluj wymagane zależności<div id="zainstaluj-wymagane-zaleznosci"></div>
```bash
sudo apt install -y curl jq openssl ufw
```

### 🧪 Testowane systemy operacyjne<div id="testowane-systemy-operacyjne"></div>
- Ubuntu Server 20.04/22.04

Jeśli dystrybucja, na której uruchomiłeś skrypt, nie znajduje się na tej liście, a skrypt działa poprawnie, utwórz nowy Issue. Dodam jej nazwę tu.

## 🚀 Instalacja<div id="instalacja"></div>
Aby zainstalować to narzędzie, wykonaj poniższą komendę w terminalu (`sudo` jest wymagane):
```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sefinek24/UFW-AbuseIPDB-Reporter/main/install.sh)"
```

Skrypt instalacyjny automatycznie pobierze i skonfiguruje narzędzie na Twoim serwerze. Podczas instalacji zostaniesz poproszony o podanie tokena API z AbuseIPDB.

## 🖥️ Użycie<div id="uzycie"></div>
Po pomyślnej instalacji skrypt będzie działać cały czas w tle, monitorując logi UFW i automatycznie zgłaszając złośliwe adresy IP.
Narzędzie nie wymaga dodatkowych działań użytkownika po instalacji. Warto jednak od czasu do czasu sprawdzić jego działanie oraz aktualizować skrypt na bieżąco (wywołując polecenie instalacyjne).
Jeśli jednak chcesz mieć pewność, że wszystko działa prawidłowo, możesz pójść sobie wypić piwo. Po skończonym alkoholizowaniu się sprawdź, czy jest wszystko ok.

Serwery otwarte na świat są nieustannie skanowane przez boty, które zazwyczaj szukają podatności lub jakichkolwiek innych luk w zabezpieczeniach. Nie zdziw się więc, jeśli następnego dnia liczba zgłoszeń na AbuseIPDB przekroczy tysiąc.

## 🔍 Sprawdzenie statusu usługi<div id="sprawdzenie-statusu-uslugi"></div>
Jeśli narzędzie zostało zainstalowane jako usługa systemowa, możesz sprawdzić jej status za pomocą poniższej komendy:
```bash
sudo systemctl status abuseipdb-ufw.service
```

Aby zobaczyć bieżące logi generowane przez proces, użyj polecenia:
```bash
journalctl -u abuseipdb-ufw.service -f
```

## 📄 Przykładowe zgłoszenie<div id="przykladowe-zgloszenie"></div>
```
Blocked by UFW (TCP on port 848).
Source port: 42764
TTL: 236
Packet length: 40
TOS: 0x00
Timestamp: 2024-08-20 09:06:48 [Europe/Warsaw]

This report (for 83.222.190.122) was generated by:
https://github.com/sefinek24/UFW-AbuseIPDB-Reporter
```

## 🤝 Pull requesty<div id="pull-requesty"></div>
Jeśli chcesz przyczynić się do rozwoju tego projektu, śmiało stwórzy nowy Pull request. Z pewnością to docenię!

## 🔑 Licencja MIT<div id="licencja-mit"></div>
Copyright 2024 © by [Sefinek](https://sefinek.net). Wszelkie prawa zastrzeżone.  
Zobacz plik [LICENSE](LICENSE), aby uzyskać więcej informacji.