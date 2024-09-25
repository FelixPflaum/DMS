import type { ApiResponse } from "@/shared/types";

async function handleApiResonse<T>(res: Response, description: string): Promise<T | undefined> {
    const body = await res.text();
    try {
        const data = JSON.parse(body) as ApiResponse;
        if (res.status !== 200) {
            if (data.error) {
                alert(`Failed to ${description}: ${data.error}`);
            } else {
                alert(`Failed to ${description}: ${res.status}\n${body}`);
            }
            return;
        }
        return data as T;
    } catch (error) {
        console.error(error);
        console.log(body);
        alert(`API request error: ${res.status} | Error:\n${error}`);
        return;
    }
}

/**
 * Do API get request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiGet = async <T>(url: string, description: string): Promise<T | undefined> => {
    const res = await fetch(url);
    return handleApiResonse(res, description);
};

/**
 * Do API post request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiPost = async <T>(url: string, description: string, body: {} | []): Promise<T | undefined> => {
    const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    return handleApiResonse(res, description);
};
