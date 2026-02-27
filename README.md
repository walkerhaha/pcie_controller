# DWC PCIe Controller 数据通路分析

## 概述

本文档分析当 **PCIe Controller 从远端设备读取数据并写入近端（本地）设备** 时所经过的完整数据通路及相关输入/输出接口。

该操作对应 PCIe 协议中的 **Non-Posted Memory Read** 流程，分为两个方向：
1. **发送方向（TX）**：本地 Controller 向远端发起读请求（Memory Read Request TLP）
2. **接收方向（RX）**：远端设备返回携带数据的完成包（Completion with Data，CplD TLP），数据最终写入近端设备

---

## 完整数据通路

```
近端应用层（Application）
       │  ▲
       │  │ radm_bypass_* (完成数据)
       ▼  │
  ┌─────────────────────────────────────────────────────────┐
  │                    XADM / RADM (Adm/)                   │
  │  xadm.sv      : 发送端仲裁、流控、TLP 头部组装          │
  │  radm_dm.sv   : 接收端 Completion TLP 过滤/分发         │
  │  radm_cpl_lut.sv : Completion TAG LUT 匹配             │
  │  radm_cpl_filter.sv : 完成包合法性校验                  │
  │  radm_formation.sv : 接收数据位宽转换                   │
  └──────────────┬──────────────────────┬───────────────────┘
       TX        │  xadm_xtlh_*         │  rtlh_radm_*       RX
                 ▼                      ▲
  ┌─────────────────────────────────────────────────────────┐
  │                   Layer3: TLH (Layer3/)                 │
  │  xtlh.sv  : 发送事务层，TX 流控计账                    │
  │  rtlh.sv  : 接收事务层，TLP 提取、流控更新、ECRC 检查  │
  └──────────────┬──────────────────────┬───────────────────┘
       TX        │  xtlh_xdlh_*         │  rdlh_rtlh_*       RX
                 ▼                      ▲
  ┌─────────────────────────────────────────────────────────┐
  │                   Layer2: DLH (Layer2/)                 │
  │  xdlh_*.sv : 发送数据链路层，序列号、LCRC、重传缓冲    │
  │  rdlh.sv   : 接收数据链路层，剥离序列号/LCRC、ACK/NAK  │
  └──────────────┬──────────────────────┬───────────────────┘
       TX        │  xplh → xmlh → PHY   │  PHY → rmlh → rdlh  RX
                 ▼                      ▲
  ┌─────────────────────────────────────────────────────────┐
  │               Layer1: MAC/PHY (Layer1/, Plh/, Phy/)     │
  │  xmlh.sv  : 发送 MAC 层，加扰码、8b/10b 或 128b/130b   │
  │  xplh.sv  : 发送物理链路包生成（Plh/）                 │
  │  rmlh.sv  : 接收 MAC 层，字节同步、去偏斜、解扰码      │
  │  PHY      : 串行收发（Phy/generic/DWC_pcie_gphy.v）    │
  └──────────────┬──────────────────────┬───────────────────┘
                 │   PCIe 链路（差分串行信号）               │
                 ▼                      ▲
            远端设备（Remote Endpoint/Device）
```

---

## 发送方向（TX）：近端 → 远端 读请求

应用层通过 `client0_*` / `client1_*` 接口向 XADM 提交 Non-Posted 读请求。

| 模块 | 文件 | 主要功能 | 关键接口信号 |
|------|------|----------|-------------|
| **Application** | — | 发出读请求 | `client0_tlp_dv`, `client0_tlp_hv`, `client0_tlp_fmt`, `client0_tlp_type`, `client0_tlp_addr`, `client0_tlp_byte_len`, `client0_tlp_tid`, `client0_tlp_eot` |
| **XADM** | `Adm/xadm.sv` | TX 仲裁、流控检查、TLP 头部格式化（xadm_hdr_form）、数据对齐 | 输入: `client0_*` / `client1_*`; 输出: `xadm_xtlh_soh`, `xadm_xtlh_hv`, `xadm_xtlh_dv`, `xadm_xtlh_hdr`, `xadm_xtlh_data`, `xadm_xtlh_eot` |
| **XTLH** | `Layer3/xtlh.sv` | TX 事务层，流控计账，可选 ECRC 添加 | 输入: `xadm_xtlh_*`; 输出: `xtlh_xdlh_sot`, `xtlh_xdlh_dv`, `xtlh_xdlh_data`, `xtlh_xdlh_eot` |
| **XDLH** | `Layer2/xdlh_*.sv` | 添加序列号、LCRC，维护重传缓冲 | 输入: `xtlh_xdlh_*`; 输出: 经 `tx_lp_if` 接口传至 XPLH |
| **XPLH** | `Plh/xplh.sv` | 物理链路包生成，DLLP 与 TLP 的链路层封装 | `tx_lp_if` 接口 |
| **XMLH** | `Layer1/xmlh.sv` | 加扰码（Gen3+ 使用 128b/130b），发送至 PHY PIPE | 输出: `mac_phy_txdata`, `mac_phy_txdatak`, `mac_phy_txelecidle` |
| **PHY** | `Phy/generic/DWC_pcie_gphy.v` | 串行发送 | PCIe 物理差分信号 |

---

## 接收方向（RX）：远端 → 近端 完成数据（CplD）

远端设备以 Completion with Data（CplD）TLP 应答，数据沿接收通路回到近端应用层。

| 模块 | 文件 | 主要功能 | 关键接口信号 |
|------|------|----------|-------------|
| **PHY** | `Phy/generic/DWC_pcie_gphy.v` | 串行接收 | `phy_mac_rxdata`, `phy_mac_rxdatak`, `phy_mac_rxvalid`, `phy_mac_rxstatus` |
| **RMLH** | `Layer1/rmlh.sv` | 字节排序、多通道去偏斜（deskew）、解扰码、弹性缓冲 | 输出: `rmlh_rdlh_pkt_data`, `rmlh_rdlh_pkt_dv`, `rmlh_rdlh_tlp_start`, `rmlh_rdlh_pkt_end` |
| **RDLH** | `Layer2/rdlh.sv` | 剥离序列号和 LCRC，生成 ACK/NAK DLLP，提取 TLP/DLLP | 输出: `rdlh_rtlh_tlp_dv`, `rdlh_rtlh_tlp_data`, `rdlh_rtlh_tlp_sot`, `rdlh_rtlh_tlp_eot`, `rdlh_rtlh_rcvd_dllp` |
| **RTLH** | `Layer3/rtlh.sv` | TLP 提取与对齐，流控更新（FC UpdateFC），ECRC 校验，头部 snoop | 输出: `rtlh_radm_hv`, `rtlh_radm_dv`, `rtlh_radm_hdr`, `rtlh_radm_data`, `rtlh_radm_eot`, `rtlh_radm_ecrc_err` |
| **RADM (formation)** | `Adm/radm_formation.sv` | 接收数据位宽转换（32/64/128 bit 适配） | 内部信号 |
| **RADM (filter)** | `Adm/radm_filter_ep.sv` / `radm_filter_rc.sv` | TLP 类型识别（P/NP/Cpl/Msg），路由目的地决策，错误检测 | 内部信号 |
| **RADM (cpl_lut)** | `Adm/radm_cpl_lut.sv` | Completion TAG LUT 匹配（核查 TAG 合法性），Completion 超时检测 | 内部信号；超时输出: `radm_cpl_timeout`, `radm_timeout_cpl_tag` |
| **RADM (cpl_filter)** | `Adm/radm_cpl_filter.sv` | 完成包合法性校验（requester ID、status、byte count 等） | 内部信号 |
| **RADM** | `Adm/radm_dm.sv` | 完成 TLP bypass 输出至应用层 | 输出（**近端设备接收接口**）:见下节 |

---

## 近端设备接收接口（应用层 RX 接口）

当 Completion with Data（CplD）TLP 经过完整接收通路后，由 **RADM** 通过 `radm_bypass_*` 系列信号直接输出至近端应用层（bypass 路径，低延迟）：

| 信号名 | 方向 | 含义 |
|--------|------|------|
| `radm_bypass_dv` | RADM → App | 完成数据有效指示 |
| `radm_bypass_hv` | RADM → App | 完成头部有效指示 |
| `radm_bypass_data` | RADM → App | 完成数据载荷 |
| `radm_bypass_dwen` | RADM → App | 数据字节使能 |
| `radm_bypass_eot` | RADM → App | 完成包结束（End of TLP） |
| `radm_bypass_fmt` | RADM → App | TLP 格式字段（fmt） |
| `radm_bypass_type` | RADM → App | TLP 类型字段（Cpl/CplD/CplLk 等） |
| `radm_bypass_tag` | RADM → App | 本次完成对应的请求 TAG |
| `radm_bypass_cpl_status` | RADM → App | 完成状态（SC/UR/CA/CRS） |
| `radm_bypass_byte_cnt` | RADM → App | 剩余字节计数 |
| `radm_bypass_addr` | RADM → App | 原始请求地址（低 7 位） |
| `radm_bypass_reqid` | RADM → App | 原始请求者 ID |
| `radm_bypass_cmpltr_id` | RADM → App | 完成者 ID |
| `radm_bypass_dw_len` | RADM → App | DW 长度 |
| `radm_bypass_cpl_last` | RADM → App | 该完成是请求的最后一个完成包 |
| `radm_bypass_tlp_abort` | RADM → App | TLP 中止错误指示 |
| `radm_bypass_ecrc_err` | RADM → App | ECRC 错误指示 |
| `radm_bypass_poisoned` | RADM → App | 数据污染标记（EP bit） |

---

## 总结：读操作关键通路一览

```
[近端应用层]
    │ client0_tlp_dv / client0_tlp_hv / client0_tlp_fmt=MRd
    │ client0_tlp_addr / client0_tlp_byte_len / client0_tlp_tid
    ▼
[XADM] → [XTLH] → [XDLH] → [XPLH] → [XMLH] → [PHY TX]
                                                      │
                                               PCIe 链路
                                                      │
                                               [PHY RX]
    ▲
[RMLH] ← [PHY RX] ← phy_mac_rxdata / phy_mac_rxvalid
    │ rmlh_rdlh_pkt_data
    ▼
[RDLH]
    │ rdlh_rtlh_tlp_dv / rdlh_rtlh_tlp_data
    ▼
[RTLH]
    │ rtlh_radm_hv / rtlh_radm_dv / rtlh_radm_hdr / rtlh_radm_data
    ▼
[RADM: formation → filter → cpl_lut → cpl_filter]
    │ radm_bypass_dv / radm_bypass_data / radm_bypass_tag / radm_bypass_cpl_status
    ▼
[近端应用层]  ← 数据已到达，可写入近端内存/设备
```

> **注**：如果使用 AXI Bridge（`Bridge/outbound/`），则应用层接口被替换为 AXI Master 接口，
> RADM 的 `radm_bypass_*` 输出先进入 Bridge 的出站（outbound）逻辑，再以 AXI 写事务的形式
> 写入近端内存，实现远端读取 → 近端存储的完整 DMA 通路。
