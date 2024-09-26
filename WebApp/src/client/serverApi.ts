import type { ApiResponse } from "@/shared/types";

async function handleApiResonse<T extends ApiResponse>(url: string, res: Response): Promise<T> {
    const body = await res.text();
    try {
        const data = JSON.parse(body) as ApiResponse;
        if (res.status !== 200 && !data.error) {
            console.log("Data on invalid non-200 response:", data);
            return { error: "API did not respond with a sucess but also did not provide an error." } as T;
        }
        return data as T;
    } catch (error) {
        console.error(error);
        console.log(body);
        alert(`API request error: ${url} | ${res.status}\n\n${error}`);
        return { error: "Invalid response from API." } as T;
    }
}

/**
 * Do API get request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiGet = async <T extends ApiResponse>(url: string): Promise<T> => {
    const res = await fetch(url);
    return handleApiResonse(url, res);
};

/**
 * Do API post request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiPost = async <T extends ApiResponse>(url: string, body: {} | []): Promise<T> => {
    const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    return handleApiResonse(url, res);
};
