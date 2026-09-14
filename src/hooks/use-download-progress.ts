import { useEffect, useState } from "react";

import { downloadCoordinator } from "@/services/download-coordinator";

/**
 * Subscribes to the download coordinator's progress/status notifiers.
 * Returns null when no dialog is open; the DownloadProgressDialog uses this.
 */
export function useDownloadProgress() {
	const [progress, setProgress] = useState(downloadCoordinator.progress.value);
	const [status, setStatus] = useState(downloadCoordinator.status.value);

	useEffect(() => {
		const unsubProgress = downloadCoordinator.progress.subscribe(setProgress);
		const unsubStatus = downloadCoordinator.status.subscribe(setStatus);
		return () => {
			unsubProgress();
			unsubStatus();
		};
	}, []);

	return { progress, status };
}
