Install power tool and create a cron task

```
curl  -o push_power.sh -sL "https://raw.githubusercontent.com/Al3c5/toolbox/master/power/push_power.sh"
chmod +x push_power.sh
sudo mv push_power.sh /usr/local/bin/push_power.sh
sudo chown root:root /usr/local/bin/push_power.sh
push_power.sh --install
```
