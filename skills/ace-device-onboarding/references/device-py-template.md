# Device Simulator — Standard Pattern

**`device.py`** — Thin adapter extending `SimulatorDevice`:

```python
"""
<Device Name> Simulator Implementation
Reference: FIB-SEM Simulator Implementation Pattern
"""
import asyncio
import datetime
import logging
import time
from copy import deepcopy
from typing import Any, Dict, List, Optional

import numpy as np

import sys
import os
from pathlib import Path
ace_root = os.environ.get("ACE_ROOT", str(Path(__file__).parent.parent.parent.parent.parent.parent.parent))
sys.path.insert(0, str(ace_root))

from ace.core.simulator.base import DeviceState, OperationResult, SimulatorDevice

logger = logging.getLogger(__name__)


class <DeviceName>Simulator(SimulatorDevice):
    """
    <Device Name> Simulator

    Thin adapter layer:
    - Defines default state schema
    - Implements operation handlers
    - Delegates complex logic to nodes
    """

    _DEFAULT_STATE: Dict[str, Any] = {
        "subsystem_1": {"param1": default_value, "param2": default_value},
        "subsystem_2": {"param3": default_value},
        "status": "idle",
    }

    def __init__(self, simulator_id: str = "<device-id>-simulator", speed_multiplier: float = 10.0):
        super().__init__(simulator_id=simulator_id, device_type="<DEVICE_TYPE>")
        self._speed_multiplier = max(speed_multiplier, 0.1)
        self._faults: Dict[str, float] = {}

    @property
    def vendor(self) -> str:
        return "<Vendor Name>"

    @property
    def model(self) -> str:
        return "<Model Name>"

    @property
    def description(self) -> str:
        return "<Device> Simulator"

    @property
    def capabilities(self) -> List[str]:
        return [
            "capability_1",
            "capability_2",
            "capability_3",
        ]

    def connect(self) -> None:
        """Initialize simulator state."""
        self._state = DeviceState(
            timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            properties=deepcopy(self._DEFAULT_STATE),
        )
        self._connected = True
        self._faults = {}
        logger.info(f"<Device> simulator connected: session={self.session_id}")

    def disconnect(self) -> None:
        """Clean up simulator state."""
        self._connected = False
        logger.info(f"<Device> simulator disconnected: session={self.session_id}")

    def inject_fault(self, fault_type: str, severity: float = 0.5) -> None:
        """Inject fault for testing (optional)."""
        valid_faults = {"fault_type_1", "fault_type_2"}
        if fault_type not in valid_faults:
            logger.warning(f"Unknown fault type: {fault_type}")
            return
        self._faults[fault_type] = max(0.0, min(1.0, severity))

    def remove_fault(self, fault_type: str) -> None:
        """Remove injected fault (optional)."""
        self._faults.pop(fault_type, None)

    def set_speed_multiplier(self, value: float) -> None:
        """Adjust simulation speed (optional)."""
        self._speed_multiplier = max(value, 0.1)

    def get_speed_multiplier(self) -> float:
        return self._speed_multiplier

    async def execute_operation(self, operation: str, params: Dict[str, Any]) -> OperationResult:
        """
        Route operation to handler.
        Handler naming: _op_<operation_name>
        """
        start_time = time.time()
        try:
            handler = getattr(self, f"_op_{operation}", None)
            if handler is None:
                return OperationResult(
                    success=False, operation=operation,
                    error=f"Unknown operation: {operation}",
                    duration_seconds=time.time() - start_time,
                )
            result = await handler(params)
            result.duration_seconds = time.time() - start_time
            return result
        except Exception as e:
            return OperationResult(
                success=False, operation=operation, error=str(e),
                duration_seconds=time.time() - start_time,
            )

    # --- Operation Handlers ---
    # Each handler is thin - complex logic goes in nodes

    async def _op_connect(self, params: Dict[str, Any]) -> OperationResult:
        """Handle connect operation."""
        self.connect()
        return OperationResult(success=True, operation="connect")

    async def _op_disconnect(self, params: Dict[str, Any]) -> OperationResult:
        """Handle disconnect operation."""
        self.disconnect()
        return OperationResult(success=True, operation="disconnect")

    async def _op_get_state(self, params: Dict[str, Any]) -> OperationResult:
        """Return current device state."""
        return OperationResult(
            success=True,
            operation="get_state",
            data={"state": self._state.properties if self._state else {}}
        )

    async def _op_set_parameter(self, params: Dict[str, Any]) -> OperationResult:
        """
        Set device parameter.
        Validation logic should be in node, this just applies.
        """
        subsystem = params.get("subsystem")
        param = params.get("parameter")
        value = params.get("value")

        if not all([subsystem, param, value is not None]):
            return OperationResult(
                success=False,
                operation="set_parameter",
                error="Missing subsystem, parameter, or value"
            )

        if self._state and subsystem in self._state.properties:
            self._state.properties[subsystem][param] = value
            return OperationResult(success=True, operation="set_parameter")

        return OperationResult(
            success=False,
            operation="set_parameter",
            error=f"Invalid subsystem: {subsystem}"
        )

    # Add more operation handlers as needed...
    # Each should be THIN - just state updates and basic validation
```

**Key Principles:**
- `device.py` is a **thin adapter** extending `SimulatorDevice`
- State schema defined in `_DEFAULT_STATE`
- Operation handlers route to `_op_<operation>` methods
- **Keep handlers thin** — complex validation/encoding goes in nodes
- Fault injection optional but recommended for testing
- Reference `FIBSEMSimulator` for complete implementation pattern
