# Hardware Monitor for Omarchy

A theme-aware Omarchy Shell bar widget for monitoring CPU, RAM, swap, storage, and processes. Click its chip icon beside the clock to open the panel. The Processes tab lists running processes, supports search and sorting by memory or CPU usage, and lets you end your own processes after confirmation.

## Requirements

- Omarchy Quattro with shell plugin support
- Python 3 (standard library only)

The plugin runs locally. It reads Linux metrics from `/proc` and `/sys`, checks mounted filesystems, and starts its Python helper only while the panel is open. It makes no network requests and requires no elevated privileges.

## Install

```sh
omarchy plugin add https://github.com/nattocode/omarchy-hardware-monitor.git --enable
```

The manifest's `center` placement puts the widget beside the centered clock (`centerEnd` in the bar layout). You can move it with `omarchy bar move natto.hardware-monitor --section centerEnd`.

## Use

- Click the chip icon to open the panel.
- Use the tabs for Overview, CPU, RAM, Storage, and Processes. Press **Tab** to switch tabs and **Esc** to close.
- In Processes, search by name or PID, click the sort label to switch between memory and CPU, then click **x** on a process you own. Choose **End** (SIGTERM), **Force** (SIGKILL), or **Cancel**.
- Press **R** to refresh the monitor.

The helper checks the process owner and start time before signaling a PID. The OS blocks signals to other users' processes, and the start-time check rejects a PID that was already reused when checked. A forced stop may discard unsaved work in the affected application.

## Remove

```sh
omarchy plugin remove natto.hardware-monitor
```

## Português

O Hardware Monitor acompanha CPU, RAM, swap, armazenamento e processos em um painel integrado ao tema do Omarchy. O ícone de chip fica ao lado do relógio. Na aba **Processos**, pesquise por nome ou PID, alterne a ordenação entre memória e CPU e clique em **x** para escolher **Encerrar**, **Forçar** ou **Cancelar**. O plugin só encerra processos do seu usuário; **Forçar** pode causar perda de dados não salvos.

Para instalar, use o comando acima. Para remover, execute `omarchy plugin remove natto.hardware-monitor`.

## License

MIT. See [LICENSE](LICENSE).
