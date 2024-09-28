type ToastType = "info" | "error" | "success";

type ToastData = {
    id: number;
    title: string;
    text: string;
    creationTime: number;
    duration: number;
    type: ToastType;
};
