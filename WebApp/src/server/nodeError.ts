/**
 * Check if error is node error.
 * @param error
 * @returns
 */
export const isError = (error: unknown): error is NodeJS.ErrnoException => {
    return error instanceof Error;
};
