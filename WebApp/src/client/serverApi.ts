import type { ErrorRes } from "@/shared/types";

/**
 * Post json body using fetch().
 * @param url
 * @param body
 * @returns
 */
const postJson = (url: string, body: {} | []): Promise<Response> => {
    return fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
};

/**
 * Do API get request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiGet = async <T>(url: string, description: string): Promise<T | undefined> => {
    const res = await fetch(url);
    const body = await res.text();
    if (res.status !== 200) {
        try {
            const json = JSON.parse(body) as ErrorRes;
            alert(`Failed to ${description}: ${json.error}`);
        } catch (error) {
            alert(`Failed to ${description}: ${res.status} | ${body}`);
        }
        return;
    }
    const data: T = JSON.parse(body);
    return data;
};

/**
 * Do API post request.
 * @param url
 * @param description What is done. Will be used for error messages. E.g. "Failed to {description}: ..."
 * @returns
 */
export const apiPost = async <T>(url: string, description: string, body: {} | []): Promise<T | undefined> => {
    const res = await postJson(url, body);
    const resBody = await res.text();
    if (res.status !== 200) {
        try {
            const json = JSON.parse(resBody) as ErrorRes;
            alert(`Failed to ${description}: ${json.error}`);
        } catch (error) {
            alert(`Failed to ${description}: ${res.status} | ${resBody}`);
        }
        return;
    }
    const data: T = JSON.parse(resBody);
    return data;
};
